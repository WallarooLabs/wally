#!/usr/bin/env python3

from abc import ABC, abstractmethod
import asyncore
import asynchat
import logging
import math
import os
import random
import re
import socket
import struct
import sys
import threading
import time
import traceback

if os.environ.get('USE_FAKE_S3', '') == 'on':
    import boto3

from wallaroo.experimental import connector_wire_messages as cwm

# NOTES:
#
# 1. This server will truncate the out_path & out_path+".txnlog" files.
#    If you want to preserve their data, then move them out of the way
#    before starting this server.

## Class from dos_server.py

class ThreadSafeDict(dict) :
    def __init__(self, * p_arg, ** n_arg) :
        dict.__init__(self, * p_arg, ** n_arg)
        self._lock = threading.Lock()

    def __enter__(self) :
        self._lock.acquire()
        return self

    def __exit__(self, type, value, traceback) :
        self._lock.release()

TXN_COUNT = 0
active_workers = ThreadSafeDict()

def parse_abort_rules(path):
    th = TwoPC_TxnlogHelper
    a = []
    try:
        with open(path, 'rb') as f:
            for l in f:
                a.append(th.deserialize_txnlog_item(l))
        return a
    except FileNotFoundError:
        return []

def reload_phase1_txn_state(lines, instance_name):
    th = TwoPC_TxnlogHelper
    txn_state = {}
    for l in lines:
        a = th.deserialize_txnlog_item(l)
        if a[1] == '1-ok':
            txn_state[a[2]] = (True, a[3])
        if a[1] == '1-rollback':
            txn_state[a[2]] = (False, a[3])
        if (a[1] == '2-ok') or (a[1] == '2-rollback'):
            del txn_state[a[2]]
    if len(txn_state) > 1:
        logging.critical('reload_phase1_txn_state: bad txn_state: {} instance {}'.format(txn_state, instance_name))
        sys.exit(66)
    return txn_state

def look_for_forced_abort(lines, instance_name):
    th = TwoPC_TxnlogHelper
    res = True # res will become self._txn_commit_next's value
    for l in lines:
        a = th.deserialize_txnlog_item(l)
        if a[1] == 'next-txn-force-abort':
            res = False
        elif a[1] == '1-ok':
            if res == False:
                logging.critical('next-txn-force-abort followed by 1-ok, worker {}'.format(instance_name))
                sys.exit(66)
            res = True
        elif a[1] == '1-rollback':
            res = True
    return res

def look_for_orphaned_s3_phase2_data(lines, instance_name):
    th = TwoPC_TxnlogHelper
    orphaned = {}
    for l in lines:
        a = th.deserialize_txnlog_item(l)
        op = a[1]
        txn_id = a[2]
        if op == '1-ok':
            where_list = a[3]
            if where_list == []:
                logging.critical('Empty where_list in {} worker {}'.format(l, instance_name))
                sys.exit(66)
            for (stream_id, start_por, end_por) in where_list:
                if stream_id != 1:
                    logging.critical('Bad stream_id in {} worker {}'.format(l, instance_name))
                    sys.exit(66)
            ## The first txn commit may be start=end=0.
            ## We don't write an S3 object for 0 bytes,
            ## so we don't include this case in orphaned.
            if (start_por == 0 and end_por == 0):
                ## Pretend that we've seen the 2-ok for 0 & 0.
                ## Then it will be filtered by the list comprehension
                ## at the end of this func.
                orphaned[txn_id] = (txn_id, start_por, end_por, True)
            else:
                orphaned[txn_id] = (txn_id, start_por, end_por, False)
        elif op == '2-ok':
            if not (txn_id in orphaned):
                logging.critical('Expected txn_id {} in {} worker {}'.format(txn_id, l, instance_name))
                sys.exit(66)
            logging.debug('2-ok l = {}'.format(l))
            logging.debug('blah = {}'.format(orphaned[txn_id]))
            q = orphaned[txn_id]
            orphaned[txn_id] = (q[0], q[1], q[2], True)
        elif op == '2-s3-ok':
            try:
                del orphaned[txn_id]
            except:
                None # Should only happen in debugging/testing scenarios
    return list(x for x in orphaned.values() if x[3] == False)

def find_last_committed_offset(lines):
    th = TwoPC_TxnlogHelper
    offset = 0
    for l in lines:
        a = th.deserialize_txnlog_item(l)
        if a[1] == '2-ok':
            offset = a[3]
    return offset

def read_chunk(path, start_offset, end_offset, delete_me_entire_func_maybe):
    """
    Return only if 100% successful.
    """
    try:
        with open(path, 'rb') as f:
            f.seek(start_offset)
            return f.read(end_offset - start_offset)
    except FileNotFoundError as e:
        raise e

HACK = 0

class AsyncServer(asynchat.async_chat, object):
    def __init__(self, handler_id, sock, abort_rule_path, s3_scheme, s3_bucket, s3_prefix,
                 streams=None, using_2pc=True, twopc_out=None):
        logging.info("AsyncServer.__init__: {} {}".format(handler_id, sock))
        self._id = handler_id
        self._conn = sock
        self._abort_rule_path = abort_rule_path
        asynchat.async_chat.__init__(self, sock=self._conn)
        self.in_buffer = []
        self.out_buffer = []
        self.reading_header = True
        self.set_terminator(4) # first frame header
        self.in_handshake = True
        self._streams = {} if streams is None else streams
        self.received_count = 0
        self._reset_count = {}
        self._using_2pc = using_2pc
        self._txn_stream_content = []
        self._next_txn_force_abort_written = False
        if s3_scheme == 'fake-s3':
            self._s3 = boto3.resource('s3', endpoint_url='http://localhost:4569',
                    aws_access_key_id='fakeid', aws_secret_access_key='fakekey')
        elif s3_scheme == 's3':
            # Rely on environment vars AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY
            self._s3 = boto3.resource('s3')
        else:
            self._s3 = None
        self._s3_chunk = b''
        self._s3_bucket = s3_bucket
        self._s3_prefix = s3_prefix
        self._twopc_out = twopc_out
        # Items that are initialized later, set to nonsense None now
        self._txn_state = None
        self._abort_rules = None
        self._worker_name = None
        self._last_committed_offset = None
        self._last_msg = None
        self._output_offset = None

        if self._s3 is not None:
            try:
                self._s3 = self._s3.create_bucket(Bucket=self._s3_bucket)
            except Exception as e:
                logging.critical('{}'.format(e))
                sys.exit(66)

    def collect_incoming_data(self, data):
        """Buffer the data"""
        self.in_buffer.append(data)

    def found_terminator(self):
        """Data is going to be in two parts:
        1. a 32-bit unsigned integer length header
        2. a payload of the size specified by (1)
        """
        if self.reading_header:
            # Read the header and set the terminator size for the payload
            self.reading_header = False
            h = struct.unpack(">I", b"".join(self.in_buffer))[0]
            self.in_buffer = []
            self.set_terminator(h)
        else:
            # Read the payload and pass it to _handle_frame
            frame_data = b"".join(self.in_buffer)
            self.in_buffer = []
            self.set_terminator(4) # read next frame header
            self.reading_header = True
            try:
                self._handle_frame(frame_data)
            except Exception as e:
                logging.critical('_handle_frame error: {}'.format(e))
                _type, _value, _traceback = sys.exc_info()
                exc_text = ''.join(
                        traceback.format_exception(_type, _value, _traceback)).strip()
                logging.critical('_handle_frame error: {}'.format(exc_text))
                sys.exit(66)

    def _handle_frame(self, frame):
        self.update_received_count()
        msg = cwm.Frame.decode(frame)
        # Hello, Ok, Error, Notify, NotifyAck, Message, Ack, Restart
        self.count = 0
        if isinstance(msg, cwm.Hello):
            logging.info("Got HelloMsg: {} on {}".format(msg, self._conn))
            if msg.version != "v0.0.1":
                logging.critical('bad protocol version: {}'.format(msg.version))
                sys.exit(66)
            if msg.cookie != "Dragons-Love-Tacos":
                logging.critical('bad cookie: {}'.format(msg.cookie))
                sys.exit(66)

            # As of 2019-03-04, Wallaroo's connector sink is not managing
            # credits and will rely solely on TCP backpressure for its
            # own backpressure signalling.

            self._worker_name = msg.instance_name
            global active_workers
            with active_workers as active_workers_l:
                if self._worker_name in active_workers_l:
                    ## The most likely causes of this error are:
                    ## 1. Misconfiguration, e.g., two different Wallaroo
                    ##    clusters trying to use the same sink.
                    ## 2. A Wallaroo cluster that uses sink parallelism > 1.
                    ##    The sink connector protocol doesn't support more
                    ##    than one connection per worker.  If the sink
                    ##    parallelism management can include the sink ID #
                    ##    or sink instance or something repeatable, then
                    ##    perhaps we can add that ID thingie into the
                    ##    protocol.  But this would have to be a stable
                    ##    indentifier that survives a Wallaroo worker crash
                    ##    then restart, *and also* it would have to be the
                    ##    sink instance that represents that same part of the
                    ##    pipeline topology before & after the restart.
                    txt = "Hello message from worker {}: already active".format(self._worker_name)
                    logging.info(txt)
                    err = cwm.Error(txt)
                    self.write(err)
                    self.close(delete_from_active_workers = False)
                else:
                    txt = "Hello message from worker {}".format(self._worker_name)
                    logging.info(txt)
                    ok = cwm.Ok(500)
                    self.write(ok)
                    active_workers_l[self._worker_name] = True
                    logging.info("Add {} to active_workers".format(self._worker_name))

            arpath = self._abort_rule_path + "." + msg.instance_name
            self._abort_rules = parse_abort_rules(arpath)
            for t in self._abort_rules:
                if t[0] == "stream-content":
                    stream_id = t[1]
                    regexp = t[2]
                    self._txn_stream_content.append((stream_id, regexp))
                    # NOTE: This type doesn't have extended disconnect control!

            self._output_offset = self._twopc_out.open(msg.instance_name)
            tl_lines = self._twopc_out.read_txnlog_lines()
            self._txn_state = reload_phase1_txn_state(tl_lines, msg.instance_name)
            logging.debug('restored txn state: {}'.format(self._txn_state))
            self._txn_commit_next = look_for_forced_abort(tl_lines, msg.instance_name)

            orphaned = []
            if self._s3 is not None:
                orphaned = look_for_orphaned_s3_phase2_data(tl_lines)
            logging.debug('S3: orphaned {}'.format(orphaned))
            if orphaned == []:
                logging.info('found zero orphaned items')
                None
            elif len(orphaned) > 1:
                logging.critical('expected max 1 orphaned item: {} worker {}'.format(orphaned, self._worker_name))
                sys.exit(66)
            else:
                (txn_id, start_por, end_por, _) = orphaned[0]
                if False:
                    chunk = read_chunk(opath, start_por, end_por)
                    self.log_it(['orphaned', (txn_id, start_por, end_por)])
                    self.write_to_s3_and_log(start_por, chunk, txn_id, 'orphaned')
                else:
                    raise Exception("orphaned error: {}".format(orphaned))

            self._last_committed_offset = find_last_committed_offset(tl_lines)
            logging.info("last committed offset for {} is {}".format(self._worker_name, self._last_committed_offset))
            truncate_offset = None
            if len(self._txn_state) > 1:
                sys.exit("Invariant already checked elsewhere")
            elif len(self._txn_state) == 1:
                uncommitted_txn_id = list(self._txn_state.keys())[0]
                (phase1_status, where_list) = self._txn_state[uncommitted_txn_id]
                if len(where_list) != 1:
                    logging.critical('Bad where_list in {} worker {}'.format(self._txn_state, self._worker_name))
                    sys.exit(66)
                (stream_id, start_por, end_por) = where_list[0]
                if stream_id != 1:
                    logging.critical('Bad stream_id in {} worker {}'.format(self._txn_state, self._worker_name))
                    sys.exit(66)
                if phase1_status is True:
                    truncate_offset = end_por
                else:
                    truncate_offset = self._last_committed_offset
            elif len(self._txn_state) == 0:
                truncate_offset = self._last_committed_offset
            logging.info("truncate {} at offset {}".format(self._worker_name, truncate_offset))
            t_por = self._twopc_out.truncate_and_seek_to(truncate_offset)
            if t_por != truncate_offset:
                raise Exception("truncate got {} expected {}".format(
                    t_por, truncate_offset))
            self._output_offset = truncate_offset

        elif isinstance(msg, cwm.Notify):
            if msg.stream_id != 1:
                logging.error("Unsupported stream id {}".format(msg.stream_id))
                error = cwm.Error("Unsupported stream id {}".format(msg.stream_id))
                self.write(error)
                return
            # respond with notifyack
            key = (self._worker_name, msg.stream_id)
            try:
                por = self._streams[key][2]
            except:
                por = 0
            notify_ack = cwm.NotifyAck(
                True,
                msg.stream_id,
                por)
            self._streams[key] = [msg.stream_id, msg.stream_name, por]
            self.write(notify_ack)
        elif isinstance(msg, cwm.Message):
            self.handle_message(msg)
        elif isinstance(msg, cwm.EosMessage):
            self.handle_eos_message(msg)
        elif isinstance(msg, cwm.Error):
            # Got error message from worker
            # close the connection and pass msg to the error handler
            logging.error("Received an error message. closing the connection")
            self.close()
            raise Exception(msg.message)
        else:
            # write the original message back
            self.write(msg)

    def handle_eos_message(self, msg):
        # ack eos
        logging.debug("NH: acking eos for {}".format(msg))
        key = (self._worker_name, msg.stream_id)
        self.write(cwm.Ack(credits = 1,
                           acks= [(msg.stream_id, self._streams[key][2])]))

    def handle_message(self, msg):
        if msg.stream_id == 0:
            self.handle_message_stream0(msg)
        else:
            self.handle_message_streamx(msg)

    def handle_message_stream0(self, msg):
        msg2 = cwm.TwoPCFrame.decode(msg.message)
        if isinstance(msg2, cwm.ListUncommitted):
            uncommitted = list(self._txn_state.keys())
            # DEBUG only: uncommitted.append("doesnt.exist.txn.aborting-wont-hurt.-----0-0")
            reply = cwm.ReplyUncommitted(msg2.rtag, uncommitted)
            reply_bytes = cwm.TwoPCFrame.encode(reply)
            msg = cwm.Message(0, 0, 0, None, reply_bytes)
            self.write(msg)
            logging.debug('2PC: ListUncommitted resp: {}'.format(reply))

            self.log_it(['list-uncommitted', uncommitted])
        elif isinstance(msg2, cwm.TwoPCPhase1):
            logging.info('2PC: Phase 1 got {}'.format(msg2))
            logging.debug('2PC: Phase 1 txn_state = {}'.format(self._txn_state))

            # Sanity checks
            start_por = -1
            if self._output_offset != self._twopc_out.out_tell():
                self._txn_commit_next = False
                logging.error('2PC: sanity: offset {} != tell {}'.format(
                    self._output_offset, self._twopc_out.out_tell()))
            for (stream_id, start_por, end_por) in msg2.where_list:
                if stream_id != 1:
                    self._txn_commit_next = False
                    logging.error('2PC: Phase 1 invalid stream_id {} in {}'
                        .format(stream_id, msg2))
                if start_por > end_por:
                    self._txn_commit_next = False
                    logging.error('2PC: Phase 1 invalid start_por {} end_por {}'
                        .format(start_por, end_por))
                if end_por > self._output_offset:
                    self._txn_commit_next = False
                    m = '2PC: Phase 1 invalid start_por {} end_por {} self._output_offset {} file size {} msg2 {}'.format(
                        start_por, end_por, self._output_offset, self._twopc_out.out_tell(), msg2)
                    if self._output_offset == start_por:
                        ## We probably restarted, we've truncated uncommitted
                        ## bytes at the end of the file, and here's Wallaroo
                        ## starting phase 1 with a byte range that starts
                        ## exactly at that uncommitted range, and Wallaroo is
                        ## already planning to abort in phase 2.  That's OK,
                        ## we'll play along: we are already forcing this round
                        ## to abort, so Wallaroo must abort in phase 2
                        ## regardless.
                        logging.info(m)
                    else:
                        ## This is something bad that Wallaroo has done
                        logging.critical(m)
                        self.log_it(['next-txn-force-abort', m])
                        sys.exit(66)

            # Check local debugging/testing abort rules
            global TXN_COUNT
            TXN_COUNT += 1
            close_before = False
            close_after = False
            for r in self._abort_rules:
                if r[0] == 'local-txn':
                    if TXN_COUNT == r[1]:
                        try:
                            success = r[2]
                            self._txn_commit_next = success
                            logging.info('2PC: abort={} next transaction: local txn count {}'
                            .format(not success, TXN_COUNT))
                            close_before = r[3]
                            close_after = r[4]
                        except:
                            True
                elif r[0] == 'txnid-regexp':
                    if re.search(r[1], msg2.txn_id):
                        try:
                            success = r[2]
                            self._txn_commit_next = success
                            logging.info('2PC: abort={} next transaction: regexp {} matches txn_id {}'
                                .format(success, r[1], msg2.txn_id))
                            close_before = r[3]
                            close_after = r[4]
                        except:
                            True

            self._twopc_out.flush_fsync_all()
            success = self._txn_commit_next
            if False and success and (self._s3 is not None) and start_por >= 0:
                todo_opath = self._out_path + "." + msg.instance_name
                chunk = read_chunk(todo_opath, start_por, end_por)
                logging.debug('S3: offset {} to {} len(chunk) = {}'.format(start_por, end_por, len(chunk)))
                self._s3_chunk = chunk
                self._s3_chunk_offset = start_por

            self._txn_state[msg2.txn_id] = (success, msg2.where_list)
            logging.debug('2PC: Phase 1 new txn_state = {}'.format(self._txn_state))
            if success:
                log_tag = '1-ok'
            else:
                log_tag = '1-rollback'
            self.log_it([log_tag, msg2.txn_id, msg2.where_list])

            if close_before:
                self.log_it(['close', 'before reply'])
                self.close()
                return

            reply = cwm.TwoPCReply(str(msg2.txn_id).encode('utf-8'), success)
            reply_bytes = cwm.TwoPCFrame.encode(reply)
            msg = cwm.Message(0, 0, 0, None, reply_bytes)
            ##time.sleep(0.151)      ### TESTING ONLY! DELETE ME
            time.sleep(0.25)      ### TESTING ONLY! DELETE ME
            self.write(msg)

            self._txn_commit_next = True
            self._next_txn_force_abort_written = False

            if close_after:
                self.log_it(['close', 'after reply'])
                self.close()
                return
        elif isinstance(msg2, cwm.TwoPCReply):
            raise Exception("Bad stream ID 0 message: {}".format(msg2))
        elif isinstance(msg2, cwm.TwoPCPhase2):
            logging.info('2PC: Phase 2 got {}'.format(msg2))
            logging.debug('2PC: Phase 2 pre txn_state = {}'.format(self._txn_state))
            if msg2.txn_id in self._txn_state:
                (phase1_status, where_list) = self._txn_state[msg2.txn_id]
                if not msg2.commit:
                    for (stream_id, start_por, end_por) in where_list:
                        if stream_id != 1:
                            raise Exception('Phase 2 abort: bad stream_id {}'.
                                format(stream_id))
                        logging.info('2PC: truncating {} to offset {}'.format(self._worker_name, start_por))
                        logging.debug('2PC: Phase 2 got {}'.format(msg2))

                        ## DIAGNOSTIC: Save a copy of the file for diag purposes:
                        self._twopc_out.flush_fsync_out()
                        copy_path = "/tmp/sink-out/output.{}.{}".format(self._worker_name, time.time())
                        os.system("cp {} {}.diag".format(self._worker_name, copy_path))
                        logging.info("flushed & copied to {}".format(copy_path))
                        ## End DIAGNOSTIC

                        self._twopc_out.flush_fsync_out()
                        t_por = self._twopc_out.truncate_and_seek_to(start_por)
                        if t_por != start_por:
                            raise Exception("truncate got {} expected {}".format(
                                t_por, start_por))
                        self._output_offset = start_por
                        key = (self._worker_name, stream_id)
                        try:
                            self._streams[key][2] = start_por
                        except KeyError as e:
                            ## In case of disconnect, reconnect, and
                            ## ReplyUncommitted's list of txns is not empty,
                            ## then when the phase 2 abort arrives, we have
                            ## not seen a Notify message for the stream id,
                            ## this attempt to update offset will throw
                            ## an exception, which is ok here.
                            None

                if not phase1_status and msg2.commit:
                    logging.fatal('2PC: Protocol error: phase 1 status was rollback but phase 2 says commit')
                    sys.exit(66)

                if msg2.commit:
                    log_tag = '2-ok'
                    offset = where_list[0][2]
                    ## Extra sanity check
                    if self._last_committed_offset is None or \
                            offset < self._last_committed_offset:
                        logging.fatal("2PC: _last_committed_offset {} offset {} worker {}".format(
                            self._last_committed_offset, offset, self._worker_name))
                        sys.exit(66)

                    ## Remove when the protocol evolves to be unnecessary
                    if offset != self._output_offset:
                        logging.critical('2PC: phase 2 offset {} != {} worker {}'.format(
                            offset, self._output_offset, self._worker_name))
                        sys.exit(66)

                    self._last_committed_offset = offset
                else:
                    log_tag = '2-rollback'
                    offset = where_list[0][1]
                self.log_it([log_tag, msg2.txn_id, offset])

                if msg2.commit and \
                        (self._s3 is not None) and (self._s3_chunk != b''):
                    self.write_to_s3_and_log(self._s3_chunk_offset,
                        self._s3_chunk, msg2.txn_id, 'normal')

                del self._txn_state[msg2.txn_id]
                logging.debug('2PC: Phase 2 post txn_state = {}'.format(self._txn_state))
            else:
                logging.info('2PC: Phase 2 got unknown txn_id {} commit {}'.format(msg2.txn_id, msg2.commit))
                self.log_it(['2-error', msg2.txn_id, 'unknown txn_id, commit {}'.format(msg2.commit)])
            # No reply is required for Phase 2
        elif isinstance(msg2, cwm.WorkersLeft):
            None
            # Handling this message is a bit tricky because we may have
            # connections from multiple Wallaroo workers, and each one of
            # them will send the same WorkersLeft message.  Let's assume
            # that we'll be processing all of those identical messages in
            # a big race.
            #
            # TODO: The deletion step from self._streams is probably
            # not safe 100% of the time?  I.e., there might be a race with
            # a worker with the same name joining again?  That's very
            # unlikely in the current Wallaroo implementation, but possible.
            #
            self._twopc_out.leaving_workers(msg2.leaving_workers)
            for w in msg2.leaving_workers:
                # NOTE: When streamIds > 1 are used, this iteration needs change
                key = (w, 1)
                try:
                    del self._streams[key]
                except KeyError:
                    None
        else:
            raise Exception("Stream ID 0 not implemented, msg2 = {}".format(msg2))

    def handle_message_streamx(self, msg):
        bs = bytes(msg.message)

        for (stream_id, regexp) in self._txn_stream_content:
            if stream_id == msg.stream_id:
                if re.search(regexp, str(bs)):
                    self._txn_commit_next = False
                    logging.info('2PC: abort next transaction: {} matches {}'
                        .format(regexp, bs))

        key = (self._worker_name, msg.stream_id)
        if msg.message_id != None:
            logging.debug('msg.message_id = {} worker {}'.format(msg.message_id, self._worker_name))
            if self._output_offset == msg.message_id:
                (ret1, new_offset) = self._twopc_out.append_output(bs, self._output_offset)
                if len(bs) != ret1:
                    self._txn_commit_next = False
                    raise Exception("File write error? {} != {} worker {}".format(len(bs), ret1, self._worker_name))
                self._output_offset += len(bs)
                self._streams[key][2] = self._output_offset
                logging.debug('_output_offset is now {} tell {} worker {}'.format(self._output_offset, self._twopc_out.out_tell(), self._worker_name))
            elif self._output_offset < msg.message_id:
                m = 'MISSING DATA: self._output_offset {} tell {} < msg.message_id {} worker {}'.format(self._output_offset, self._twopc_out.out_tell(), msg.message_id, self._worker_name)
                self._txn_commit_next = False
                if not self._next_txn_force_abort_written:
                    self._next_txn_force_abort_written = True
                    self.log_it(['next-txn-force-abort', m])
                if self._last_msg is None:
                    # Wallaroo's internal buffering has sent us data after
                    # a gap.  However, we know that this connection is new,
                    # and this is the first message we've received.
                    logging.info(m)
                elif not self._next_txn_force_abort_written:
                    # This is bad.  This isn't the first stream id 1 message
                    # that we've received, and we don't have a reason for
                    # forcing the next txn to abort.  We could force an
                    # abort and continue, but I believe this deserves to fail.
                    logging.critical(m)
                    logging.critical("last_msg = {}".format(self._last_msg))
                    logging.critical("     msg = {}".format(msg))
                    sys.exit(66)
            elif self._output_offset > msg.message_id:
                ## The message_id has gone backward.
                logging.fatal('duplicate data: self._output_offset {} tell {} > msg.message_id {} worker {}'.format(self._output_offset, self._twopc_out.out_tell(), msg.message_id, self._worker_name))
                ## Deduplication case: we've already seen this, so
                ## we don't take any further action.

                ## DIAGNOSTIC: Let's see what's there, shall we?
                try:
                    diag = todo_read_chunk(self._out_path_opath, msg.message_id,
                        msg.message_id + len(msg.message))
                except:
                    diag = "<-<exception>->"
                if diag == msg.message:
                    logging.fatal('diag: file bytes match message worker {}'.format(self._worker_name))
                else:
                    logging.fatal('diag: msg = {} worker {}'.format(msg, self._worker_name))
                    logging.fatal('diag: bytes in opath = {} worker {}'.format(diag, self._worker_name))
                ## End DIAGNOSTIC
                self._twopc_out.flush_fsync_all()
                sys.exit(66)
        else:
            logging.critical('message has no message_id, worker {}'.format(self._worker_name))
            sys.exit(66)
        self._last_msg = msg

    def write(self, msg):
        logging.debug("write {} worker {}".format(msg, self._worker_name))
        data = cwm.Frame.encode(msg)
        super(AsyncServer, self).push(data)

    def update_received_count(self):
        self.received_count += 1
        if (not self._using_2pc) and self.received_count % 3 == 0:
            logging.debug("Sending ack for streams!")
            ack = cwm.Ack(
                credits = 10,
                acks = [
                    (sid, por)
                    for (wn,sid), _, por in self._streams.values()
                    if wn == self._worker_name ])
            logging.debug('send ack msg: {}'.format(ack))
            self.write(ack)
        if self.received_count % 9999200 == 0:
            # send a restart every 200 messages
            logging.info('PERIODIC RESTART, what could possibly go wrong?')
            self.write(cwm.Restart())

    def handle_error(self):
        _type, _value, _traceback = sys.exc_info()
        traceback.print_exception(_type, _value, _traceback)

    def close(self, delete_from_active_workers = True):
        logging.info("Closing the connection for {}, delete_from_active_workers = {}".format(self._worker_name, delete_from_active_workers))
        logging.info("last received id by stream for {}:\n\t{}".format(
            self._worker_name, self._streams))
        super(AsyncServer, self).close()
        try:
            self.log_it(['connection-closed', True])
            self._twopc_out.flush_fsync_out()
        except:
            ## In case of very early errors, file descriptors
            ## may not have been initialized yet. No harm.
            None

        if delete_from_active_workers:
            global active_workers
            with active_workers as active_workers_l:
                if not (self._worker_name in active_workers_l):
                    raise Exception("Lock not active for {}"
                        .format(self._worker_name))
                del active_workers_l[self._worker_name]
                logging.info("Remove {} from active_workers".format(self._worker_name))

    def log_it(self, log):
        log.insert(0, time.time())
        self._twopc_out.append_txnlog(log)

    def write_to_s3_and_log(self, chunk_offset, chunk, txn_id, why):
        if self._s3 is not None:
            name = '%s%016d' % (self._s3_prefix, chunk_offset)
            while True:
                try:
                    res = self._s3.put_object(
                        ACL='private',
                        Body=chunk,
                        Bucket=self._s3_bucket,
                        Key=name)
                    logging.debug('S3: put res = {}'.format(res))
                    break
                except Exception as e:
                    logging.error('S3: ERROR: put res = {}'.format(e))
                    time.sleep(2.0)
            self.log_it(['2-s3-ok', txn_id, name, why])

class SinkServer(asyncore.dispatcher):

    def __init__(self, host, port, out_path, abort_rule_path,
                 s3_scheme, s3_bucket, s3_prefix, make_twopc_output):
        asyncore.dispatcher.__init__(self)
        self.create_socket(family=socket.AF_INET, type=socket.SOCK_STREAM)
        self.set_reuse_addr()
        self.bind((host, port))
        self.listen(1)
        self._out_path = out_path
        self._abort_rule_path = abort_rule_path
        self.count = 0
        self.s3_scheme = s3_scheme
        self.s3_bucket = s3_bucket
        self.s3_prefix = s3_prefix
        self.make_twopc_output = make_twopc_output
        self._streams = {}

    def handle_accepted(self, sock, addr):
        logging.info('Incoming connection from %s' % repr(addr))
        twopc_out = self.make_twopc_output()
        handler = AsyncServer(self.count, sock,
            self._abort_rule_path,
            self.s3_scheme, self.s3_bucket, self.s3_prefix, self._streams,
            twopc_out = twopc_out)
        self.count += 1

class TwoPC_Output(ABC):
    @abstractmethod
    def open(self, instance_name):
        """
        A Wallaroo worker has used a NOTIFY message to start
        communication with this sink.
        """
        raise NotImplementedError

    @abstractmethod
    def truncate_and_seek_to(self, truncate_offset):
        """
        The sink has (re-)started and determined the last committed
        offset for this worker (open(instance_name)).
        """
        raise NotImplementedError

    @abstractmethod
    def out_tell(self):
        """Used only for sanity checking & diagnostic logging/spam."""
        raise NotImplementedError

    @abstractmethod
    def flush_fsync_all(self, yodel):
        """
        Flush all data written to output and txnlog logical streams.
        """
        raise NotImplementedError

    @abstractmethod
    def flush_fsync_out(self):
        """
        Flush all data written to output logical stream.
        """
        raise NotImplementedError

    @abstractmethod
    def flush_fsync_txnlog(self):
        """
        Flush all data written to txnlog logical stream.
        """
        raise NotImplementedError

    @abstractmethod
    def append_output(self, bs, append_offset):
        """
        Append data to worker's output logical stream at the
        specified byte offset.
        """
        raise NotImplementedError

    @abstractmethod
    def append_txnlog(self, bs):
        """
        Append data to worker's txnlog logical stream.
        """
        raise NotImplementedError

    @abstractmethod
    def read_txnlog_lines(self):
        """
        Read the entire contents of the txnlog logical stream and
        split it into an array of ASCII text lines.
        """
        raise NotImplementedError

    @abstractmethod
    def leaving_workers(self, leaving_workers):
        """
        The Connector Protocol has informed this sink that a list of
        Wallaroo workers have left the cluster.  Perform any state
        management required to clean up state related to these
        workers.
        """
        raise NotImplementedError

class TwoPC_Output_LocalFilesystem(TwoPC_Output):
    def __init__(self, out_path):
        self._out_path = out_path
        self._out = None
        self._out_offset = None
        self._txn_log = None
        self._instance_name = None
        self._th = TwoPC_TxnlogHelper

    def open(self, instance_name):
        self._instance_name = instance_name
        opath = self._out_path + "." + instance_name
        with open(opath, 'ab') as tmp:
            None # Create the file if it doesn't already exist
        self._out = open(opath, 'r+b')
        self._out.seek(0, 2) ## Seek to end of the file
        self._out_offset = self._out.tell()
        logging.debug('TwoPC_Output_LocalFilesystem.open: worker {} self._out_offset = {}'.format(instance_name, self._out_offset))

        tlpath = self._out_path + "." + instance_name + ".txnlog"
        self._txn_log = open(tlpath, 'ab')
        self._txn_log_path = tlpath

        return self._out_offset

    def truncate_and_seek_to(self, truncate_offset):
        self._out.truncate(truncate_offset)
        self._out.seek(truncate_offset)
        self._out_offset = truncate_offset
        self.flush_fsync_txnlog()
        logging.info("truncate_and_seek_to: truncate worker {} to {}".format(
            self._instance_name, truncate_offset))

        return self._out_offset

    def out_tell(self):
        """Used only for sanity checking & diagnostic logging/spam."""
        return self._out.tell()

    def flush_fsync_all(self):
        self.flush_fsync_out()
        self.flush_fsync_txnlog()

    def flush_fsync_out(self):
        self.flush_fsync(self._out)

    def flush_fsync_txnlog(self):
        self.flush_fsync(self._txn_log)

    def append_output(self, bs, append_offset):
        if append_offset != self._out_offset:
            raise Exception("append_out: worker {}: append_offset {} != _out_offset {}".format(
                self._instance_name, append_offset, self._out_offset))
        ret = self._out.write(bs)
        self._out_offset += ret
        logging.debug("write_out: ret = {} len(bs) = {} new offset {} _out_path {}".format(
            ret, len(bs), self._out_offset, self._out_path))
        return (ret, self._out_offset)

    def append_txnlog(self, log_item):
        if self._txn_log is not None:
            bs = self._th.serialize_txnlog_item(log_item)
            ret = self._txn_log.write(bs)
            self.flush_fsync_txnlog()
            return ret
        else:
            return -1

    def read_chunk(self, what, should, go, here):
        raise Exception

    def read_txnlog_lines(self):
        return self._read_file_lines(self._txn_log_path)

    def _read_file(self, path):
        with open(path, 'rb') as f:
            return f.read(-1)

    def _read_file_lines(self, path):
        a = []
        with open(path, 'rb') as f:
            for l in f:
                a.append(l)
            return a

    def flush_fsync(self, file):
        """
        Return only if 100% successful.
        """
        x = file.flush()
        if x:
            logging.critical('flush failed: {}'.format(x))
            sys.exit(66)
        x = os.fsync(file.fileno())
        if x:
            logging.critical('fsync failed: {}'.format(x))
            sys.exit(66)

    # The file naming convention we use is "output.workername.TS"
    # and "output.workername.TS.txnlog".  This scheme is compatible
    # with the "1-to-1-passthrough-verify.sh" script: it examines the
    # sink output dir for all files with ".txnlog" suffix and then
    # chops off that suffix to find the corresponding output file.
    # After that, all of "1-to-1-passthrough-verify.sh" output
    # order mapping is done by 2PC commit timestamps.
    def leaving_workers(self, leaving_workers):
        for w in leaving_workers:
            opath = self._out_path + "." + w
            mv_path1 = "{}.{}".format(opath, time.time())
            cmd1 = "mv {} {} > /dev/null 2>&1".format(opath, mv_path1)
            cmd2 = "mv {}.txnlog {}.txnlog > /dev/null 2>&1".format(opath, mv_path1)
            logging.info("leaving worker: run: {}".format(cmd1))
            logging.info("leaving worker: run: {}".format(cmd2))
            os.system(cmd1)
            os.system(cmd2)

class TwoPC_TxnlogHelper:
    def serialize_txnlog_item(log):
        if isinstance(log, list):
            return bytes("{}\n".format(log).encode('utf-8'))
        else:
            raise Exception

    def deserialize_txnlog_item(bs):
        return eval(bs)

    def is_phase1(log):
        return (is_1ok(log) or is_1bad(log))

    def is_phase2(log):
        return (is_2ok(log) or is_2bad(log))

    def is_1ok(log):
        if isinstance(log, list):
            return (log[1] == '1-ok')

    def is_1bad(log):
        if isinstance(log, list):
            return (log[1] == '1-rollback')

    def is_2ok(log):
        if isinstance(log, list):
            return (log[1] == '2-ok')

    def is_2bad(log):
        if isinstance(log, list):
            return (log[1] == '2-error') or (log[1] == '2-rollback')

    def get_1ok_offsets(log):
        [_ts, status, txn_id, [(_stream_id, start_offset, end_offset)]] = log
        if status == '1-ok':
            return (txn_id, start_offset, end_offset)
        else:
            raise Exception

    def get_2ok_end_offset(log):
        [_ts, status, _txn_id, end_offset] = log
        if status == '2-ok':
            return end_offset
        else:
            raise Exception
