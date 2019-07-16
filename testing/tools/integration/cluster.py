# Copyright 2017 The Wallaroo Authors.
#
#  Licensed under the Apache License, Version 2.0 (the "License");
#  you may not use this file except in compliance with the License.
#  You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
#  Unless required by applicable law or agreed to in writing, software
#  distributed under the License is distributed on an "AS IS" BASIS,
#  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or
#  implied. See the License for the specific language governing
#  permissions and limitations under the License.


from collections import namedtuple
import datetime
import logging
import os
import shlex
import shutil
import subprocess
import tempfile
import threading
import time


from .control import (CrashChecker,
                     SinkExpect,
                     SinkAwaitValue,
                     TryUntilTimeout,
                     WaitForClusterToResumeProcessing,
                     WaitForLogRotation)

from .end_points import (ALOSender,
                         Metrics,
                         Sender,
                         Sink)

from .errors import (ClusterError,
                    CrashedWorkerError,
                    NotEmptyError,
                    RunnerHasntStartedError,
                    SinkAwaitTimeoutError,
                    StopError,
                    TimeoutError)

from .external import (clean_resilience_path,
                      get_port_values,
                      makedirs_if_not_exists,
                      send_rotate_command,
                      send_shrink_command,
                      setup_resilience_path,
                      strftime,
                      STRFTIME_FMT)

from .logger import INFO2

from .observability import (cluster_status_query,
                           coalesce_partition_query_responses,
                           multi_states_query,
                           ObservabilityNotifier,
                           state_entity_query)

from .typed_list import TypedList

from .validations import (validate_migration,
                         validate_sender_is_flushed,
                         worker_count_matches,
                         worker_has_state_entities)

# Make string instance checking py2 and py3 compatible below
try:
    basestring
except NameError:
    basestring = str


SIGNALS = {"SIGHUP": 1,
           "SIGINT": 2,
           "SIGQUIT": 3,
           "SIGILL": 4,
           "SIGTRAP": 5,
           "SIGABRT": 6,
           "SIGIOT": 6,
           "SIGBUS": 7,
           "SIGFPE": 8,
           "SIGKILL": 9,
           "SIGUSR1": 10,
           "SIGSEGV": 11,
           "SIGUSR2": 12,
           "SIGPIPE": 13,
           "SIGALRM": 14,
           "SIGTERM": 15,
           "SIGSTKFLT": 16,
           "SIGCHLD": 17,
           "SIGCONT": 18,
           "SIGSTOP": 19,
           "SIGTSTP": 20,
           "SIGTTIN": 21,
           "SIGTTOU": 22,
           "SIGURG": 23,
           "SIGXCPU": 24,
           "SIGXFSZ": 25,
           "SIGVTALRM": 26,
           "SIGPROF": 27,
           "SIGWINCH": 28,
           "SIGIO": 29,
           "SIGPOLL": 29,
           "SIGLOST": 29,
           "SIGPWR": 30,
           "SIGSYS": 31,
           "SIGUNUSED": 31,}

class Runner(threading.Thread):
    """
    Run a shell application with command line arguments and save its stdout
    and stderr to a temporoary file.

    `get_output` may be used to get the entire output text up to the present,
    as well as after the runner has been stopped via `stop()`.
    """
    def __init__(self, command, name, control=None, data=None, external=None,
            log_dir=None):
        super(Runner, self).__init__()
        self.daemon = True
        self.command = ' '.join(v.strip('\\').strip() for v in
                                  command.splitlines())
        self.cmd_args = shlex.split(self.command)
        self.error = None
        self._file = tempfile.NamedTemporaryFile(mode='ab', dir=log_dir,
                prefix='{}.'.format(name), suffix='.log', delete=False)
        self.p = None
        self.pid = None
        self._returncode = None
        self._output = None
        self.name = name
        self.control = control
        self.data = data
        self.external = external
        self.log_dir = log_dir
        self.start_time = None

    def run(self):
        self.start_time = datetime.datetime.now()
        try:
            logging.log(INFO2, "{}: Running:\n{}".format(self.name,
                                                         self.command))
            # TODO: Figure out why this hangs sometimes!
            # Possible clue: https://github.com/dropbox/pyannotate/issues/67
            self.p = subprocess.Popen(args=self.cmd_args,
                                      stdout=self._file,
                                      stderr=subprocess.STDOUT)
            self.pid = self.p.pid
            self.p.wait()
            self._returncode = self.p.returncode
            self._output = self.get_output()
            self.p = None
            self._file = None
        except Exception as err:
            self.error = err
            logging.warning("{}: Stopped running!".format(self.name))
            raise

    def send_signal(self, signal):
        logging.log(1, "send_signal(signal={})".format(signal))
        if self.p:
            self.p.send_signal(signal)

    def stop(self):
        logging.log(1, "stop()")
        try:
            if self.p:
                self.p.terminate()
        except:
            pass

    def kill(self):
        logging.log(1, "kill()")
        try:
            if self.p:
                logging.debug("kill({})".format(self.p))
                logging.debug("is_alive() says {}".format(self.is_alive()))
                self.p.kill()
                time.sleep(0.25)
                logging.debug("is_alive() says {}".format(self.is_alive()))
                while self.is_alive():
                    logging.debug("is_alive() REDO {}".format(self.is_alive()))
                    self.p.kill()
                    time.sleep(0.25)
                    logging.debug("is_alive() REDO {}".format(self.is_alive()))
        except:
            pass

    def is_alive(self):
        logging.log(1, "is_alive()")
        if self._returncode is not None:
            return False
        elif self.p is None:
            raise RunnerHasntStartedError("Runner {} failed to start"
                .format(self.name))
        status = self.p.poll()
        if status is None:
            return True
        else:
            return False

    def poll(self):
        logging.log(1, "poll()")
        if self._returncode is not None:
            return self._returncode
        elif self.p is None:
            raise RunnerHasntStartedError("Runner {} failed to start"
                .format(self.name))
        return self.p.poll()

    def returncode(self):
        logging.log(1, "returncode()")
        if self._returncode is not None:
            return self._returncode
        elif self.p is None:
            raise RunnerHasntStartedError("Runner {} failed to start"
                .format(self.name))
        return self.p.returncode

    def get_output(self, start_from=0):
        logging.log(1, "get_output(start_from={})".format(start_from))
        if self._output:
            return self._output[start_from:]
        if self._file is not None:
            self._file.flush()
            with open(self._file.name, 'r', errors='backslashreplace') as ro:
                ro.seek(start_from)
                return ro.read()

    def tell(self):
        logging.log(1, "tell()")
        """
        Return the STDOUT file's current position
        """
        return self._file.tell() if self._file else 0

    def respawn(self):
        logging.log(1, "respawn()")
        return Runner(self.command, self.name, control=self.control,
                      data=self.data, external=self.external,
                      log_dir=self.log_dir)


BASE_COMMAND = r'''{command} \
    {{in_block}} \
    {out_block} \
    --metrics {metrics_addr} \
    --resilience-dir {res_dir} \
    --name {{name}} \
    {{initializer_block}} \
    {{worker_block}} \
    {{join_block}} \
    {{spike_block}} \
    {{alt_block}} \
    {log_rotation} \
    --ponythreads=1 \
    --ponypinasio \
    --ponynoblock'''
IN_BLOCK = r'''--in {inputs}'''
OUT_BLOCK = r'''--out {outputs}'''
INITIALIZER_CMD = r'''{worker_count} \
    --data {data_addr} \
    --external {external_addr} \
    --cluster-initializer'''
WORKER_CMD = r'''
    --my-control {control_addr} \
    --my-data {data_addr} \
    --external {external_addr}'''
JOIN_CMD = r'''--join {join_addr} \
    {worker_count}'''
CONTROL_CMD = r'''--control {control_addr}'''
WORKER_COUNT_CMD = r'''--worker-count {worker_count}'''
SPIKE_CMD = r'''--spike-drop \
    {prob} \
    {margin} \
    {seed}'''
SPIKE_SEED = r'''--spike-seed {seed}'''
SPIKE_PROB = r'''--spike-prob {prob}'''
SPIKE_MARGIN = r'''--spike-margin {margin}'''
LOG_ROTATION = r'''--log-rotation'''


def start_runners(runners, command, source_addrs, sink_addrs, metrics_addr,
                  res_dir, workers, worker_addrs=[], log_rotation=False,
                  alt_block=None, alt_func=lambda x: False, spikes={},
                  log_dir=None):
    cmd_stub = BASE_COMMAND.format(command=command,
                                   out_block=(
                                       OUT_BLOCK.format(outputs=','.join(
                                           sink_addrs))
                                       if sink_addrs else ''),
                                   metrics_addr=metrics_addr,
                                   res_dir=res_dir,
                                   log_rotation = (LOG_ROTATION if log_rotation
                                                   else ''))

    # for each worker, assign `name` and `cluster-initializer` values
    if workers < 1:
        raise ClusterError("workers must be 1 or more")
    x = 0
    if x in spikes:
        logging.info("Enabling spike for initializer")
        sc = spikes[x]
        spike_block = SPIKE_CMD.format(
            prob=SPIKE_PROB.format(prob=sc.probability),
            margin=SPIKE_MARGIN.format(margin=sc.margin),
            seed=SPIKE_SEED.format(seed=sc.seed) if sc.seed else '')
    else:
        spike_block = ''
    cmd = cmd_stub.format(
        name='initializer',
        initializer_block=INITIALIZER_CMD.format(
            worker_count=WORKER_COUNT_CMD.format(worker_count=workers),
            data_addr=worker_addrs[0][1],
            external_addr=worker_addrs[0][2]),
        in_block=(
            IN_BLOCK.format(inputs=','.join(
                '{}@{}'.format(src_nm, addr)
                for src_nm, addr in source_addrs[0].items()))
            if source_addrs else ''),
        worker_block='',
        join_block=CONTROL_CMD.format(control_addr=worker_addrs[0][0]),
        alt_block=alt_block if alt_func(x) else '',
        spike_block=spike_block)
    runners.append(Runner(command=cmd,
                          name='initializer',
                          control=worker_addrs[0][0],
                          data=worker_addrs[0][1],
                          external=worker_addrs[0][2],
                          log_dir=log_dir))
    for x in range(1, workers):
        if x in spikes:
            logging.info("Enabling spike for worker{}".format(x))
            sc = spikes[x]
            spike_block = SPIKE_CMD.format(
                prob=SPIKE_PROB.format(prob=sc.probability),
                margin=SPIKE_MARGIN.format(margin=sc.margin),
                seed=SPIKE_SEED.format(seed=sc.seed) if sc.seed else '')
        else:
            spike_block = ''
        cmd = cmd_stub.format(name='worker{}'.format(x),
                              initializer_block='',
                              in_block=(
                                  IN_BLOCK.format(inputs=','.join(
                                      '{}@{}'.format(src_nm, addr)
                                      for src_nm, addr in source_addrs[x].items()))
                                  if source_addrs else ''),
                              worker_block=WORKER_CMD.format(
                                  control_addr=worker_addrs[x][0],
                                  data_addr=worker_addrs[x][1],
                                  external_addr=worker_addrs[x][2]),
                              join_block=CONTROL_CMD.format(
                                  control_addr=worker_addrs[0][0]),
                              alt_block=alt_block if alt_func(x) else '',
                              spike_block=spike_block)
        runners.append(Runner(command=cmd,
                              name='worker{}'.format(x),
                              control=worker_addrs[x][0],
                              data=worker_addrs[x][1],
                              external=worker_addrs[x][2],
                              log_dir=log_dir))

    # start the workers, 50ms apart
    for idx, r in enumerate(runners):
        r.start()
        time.sleep(0.05)


    # check the runners haven't exited with any errors
    for idx, r in enumerate(runners):
        try:
            assert(r.is_alive())
        except RunnerHasntStartedError as err:
            for x in range(8):
                try:
                    time.sleep(0.25)
                    assert(r.is_alive())
                except:
                    if x == 7:
                        raise err
        except Exception as err:
            stdout = r.get_output()
            raise ClusterError(
                    "Runner %d of %d has exited with an error: "
                    "\n---\n%s" % (idx+1, len(runners), stdout))
        try:
            assert(r.error is None)
        except Exception as err:
            raise ClusterError(
                    "Runner %d of %d has exited with an error: "
                    "\n---\n%s" % (idx+1, len(runners), r.error))


def add_runner(worker_id, runners, command, source_addrs, sink_addrs, metrics_addr,
               control_addr, res_dir, workers,
               my_control_addr, my_data_addr, my_external_addr,
               log_rotation=False,
               alt_block=None, alt_func=lambda x: False, spikes={},
               log_dir=None):
    cmd_stub = BASE_COMMAND.format(command=command,
                                   out_block=(
                                       OUT_BLOCK.format(outputs=','.join(
                                           sink_addrs))
                                       if sink_addrs else ''),
                                   metrics_addr=metrics_addr,
                                   res_dir=res_dir,
                                   log_rotation = (LOG_ROTATION if log_rotation
                                                   else ''))

    # Test that the new worker *can* join
    if len(runners) < 1:
        raise ClusterError("There must be at least 1 worker to join!")

    if not any(r.is_alive() for r in runners):
        raise ClusterError("There must be at least 1 live worker to "
                                "join!")

    if worker_id in spikes:
        logging.info("Enabling spike for joining worker{}".format(x))
        sc = spikes[worker_id]
        spike_block = SPIKE_CMD.format(
            prob=SPIKE_PROB.format(sc.probability),
            margin=SPIKE_MARGIN.format(sc.margin),
            seed=SPIKE_SEED.format(sc.seed) if sc.seed else '')
    else:
        spike_block = ''

    cmd = cmd_stub.format(name='worker{}'.format(worker_id),
                          initializer_block='',
                          worker_block=WORKER_CMD.format(
                              control_addr=my_control_addr,
                              data_addr=my_data_addr,
                              external_addr=my_external_addr),
                          in_block=(
                              IN_BLOCK.format(inputs=','.join(
                                  '{}@{}'.format(src_nm, addr)
                                  for src_nm, addr in source_addrs[worker_id].items()))
                              if source_addrs else ''),
                          join_block=JOIN_CMD.format(
                              join_addr=control_addr,
                              worker_count=(WORKER_COUNT_CMD.format(
                                  worker_count=workers) if workers else '')),
                          alt_block=alt_block if alt_func(worker_id) else '',
                          spike_block=spike_block)
    runner = Runner(command=cmd,
                    name='worker{}'.format(worker_id),
                    control=my_control_addr,
                    data=my_data_addr,
                    external=my_external_addr,
                    log_dir=log_dir)
    runners.append(runner)

    # start the new worker
    runner.start()
    time.sleep(0.05)

    # check the runner hasn't exited with any errors
    try:
        assert(runner.is_alive())
    except RunnerHasntStartedError as err:
        for x in range(8):
            try:
                time.sleep(0.25)
                assert(runner.is_alive())
            except:
                if x == 7:
                    raise err
    except Exception as err:
        raise CrashedWorkerError
    try:
        assert(runner.error is None)
    except Exception as err:
        raise err
    return runner


RunnerData = namedtuple('RunnerData',
                        ['name',
                         'command',
                         'pid',
                         'returncode',
                         'stdout',
                         'start_time'])
SenderData = namedtuple('SenderData',
                        ['name', 'host', 'port', 'start_time', 'data'])
SinkData = namedtuple('SinkData',
                         ['name', 'host', 'port', 'start_time', 'data'])


class Cluster(object):
    base_log_dir = '/tmp/wallaroo_test_errors/current_test'

    def __init__(self, command, host='127.0.0.1', sources=[], workers=1,
            sinks=1, sink_mode='framed', split_streams=False,
            worker_join_timeout=30,
            is_ready_timeout=60, res_dir=None, log_rotation=False,
            persistent_data={}):
        # Create attributes
        self._finalized = False
        self._exited = False
        self._raised = False
        self.log_rotation = log_rotation
        self.command = command
        self.host = host
        self.workers = TypedList(types=(Runner,))
        self.dead_workers = TypedList(types=(Runner,))
        self.restarted_workers = TypedList(types=(Runner,))
        self.runners = TypedList(types=(Runner,))
        self.source_names = sources
        self.source_addrs = {}
        self.sink_addrs = []
        self.sinks = []
        self.senders = []
        self.worker_join_timeout = worker_join_timeout
        self.is_ready_timeout = is_ready_timeout
        self.metrics = Metrics(host, mode='framed')
        self.errors = []
        self._worker_id_counter = 0
        if res_dir is None:
            self.res_dir = tempfile.mkdtemp(dir='/tmp/', prefix='res-data.')
        else:
            self.res_dir = res_dir
        self.ops = []
        self.persistent_data = persistent_data
        self.log_dir = self.base_log_dir
        makedirs_if_not_exists(self.log_dir)
        # Run a continuous crash in a background thread
        self._stoppables = set()
        self.crash_checker = CrashChecker(self)
        self.crash_checker.start()
        self._stoppables.add(self.crash_checker)

        # Try to start everything... clean up on exception
        try:
            setup_resilience_path(self.res_dir)

            self.metrics.start()
            self._stoppables.add(self.metrics)
            self.metrics_addr = ":".join(
                map(str, self.metrics.get_connection_info()))

            for s in range(sinks):
                self.sinks.append(Sink(host, mode=sink_mode,
                                       split_streams=split_streams))
                self.sinks[-1].start()
                self._stoppables.add(self.sinks[-1])
                if self.sinks[-1].err is not None:
                    raise self.sinks[-1].err

            self.sink_addrs = ["{}:{}"
                               .format(*map(str,s.get_connection_info()))
                               for s in self.sinks]

            # TODO: when support for different per-worker sourced defs is
            # available, figure out how to allocate sources to workers here
            sources = len(self.source_names)
            num_ports = (sources + 3) * workers
            ports = get_port_values(num=num_ports, host=host)
            addresses = ['{}:{}'.format(host, p) for p in ports]
            (source_addrs, worker_addrs) = (
                addresses[:sources*workers],
                [addresses[sources*workers:][i:i+3]
                 for i in range(0, len(addresses[sources*workers:]), 3)])
            # Construct a list of {name: addr} dicts, one dict for each worker
            for i in range(workers):
                d = dict(zip(self.source_names,
                             source_addrs[i * sources: (i+1) * sources]))
                if d:
                    self.source_addrs[i] = d
            start_runners(self.workers, self.command, self.source_addrs,
                          self.sink_addrs,
                          self.metrics_addr, self.res_dir, workers,
                          worker_addrs, self.log_rotation,
                          log_dir = self.log_dir)
            self.runners.extend(self.workers)
            self._worker_id_counter = len(self.workers)

            # Give workers time to exit if they crashed on startup.
            # This makes these errors show faster.
            time.sleep(0.25)
            # Wait for all runners to report ready to process
            if not self._raised:
                self.wait_to_resume_processing(self.is_ready_timeout)
            # make sure `workers` runners are active and listed in the
            # cluster status query
            # But first check that we haven't already crashed!
            if not self._raised:
                logging.log(1, "Testing cluster size via obs query")
                self.query_observability(cluster_status_query,
                                         self.runners[0].external,
                                         tests=[(worker_count_matches, [workers])])
        except Exception as err:
            logging.error("Encountered and error when starting up the cluster")
            logging.exception(err)
            self.errors.append(err)
            self.__finally__()
            raise err

    #######
    # Ops #
    #######
    def log_op(self, op):
        self.ops.append(op)

    ################
    # Log Rotation #
    ################
    def rotate_logs(self, workers=None):
        """
        Rotate the named workers, or all workers if no workers are named
        """
        logging.debug("rotate_logs(workers={})".format(workers))
        if workers is None:
            logging.debug("Workers is None, getting all live ones: {}".format(
                self.workers))
            to_rotate = self.workers
        else:
            # check all named workers exist
            valid = {r.name: r for r in self.workers}
            to_rotate = []
            for w in workers:
                to_rotate.append(valid[w])  # fail if w not in valid

        prefixes = [r.name for r in to_rotate]
        logging.debug("prefixes = {}".format(prefixes))

        # start log rotation watcher
        logging.debug("Running WaitForLogRotation")
        wflr = WaitForLogRotation(cluster=self, base_path=self.res_dir,
                prefixes=prefixes)
        self._stoppables.add(wflr)
        wflr.start()

        # send a log rotate command directly to each worker's external channel
        for w in to_rotate:
            send_rotate_command(w.external, w.name)
            time.sleep(2.0) ## work-around for GH 2957

        # Wait for log rotation watcher to return
        wflr.join()
        self._stoppables.discard(wflr)
        if wflr.error:
            logging.error("WaitForLogRotation failed with:\n{!r}"
                .format(wflr.error))
            raise wflr.error
        return to_rotate

    #############
    # Autoscale #
    #############
    def grow(self, by=1, timeout=30, with_test=True):
        logging.log(1, "grow(by={}, timeout={}, with_test={})".format(
            by, timeout, with_test))
        pre_partitions = self.get_partition_data() if with_test else None
        runners = []
        sources = len(self.source_names)
        new_ports = get_port_values(num = (sources + 3) * by,
                                    host = self.host,
                                    base_port=25000)
        # format all the addresses to host:port using self.host
        addrs = ["{}:{}".format(self.host, p) for p in new_ports]
        # split addresses into worker_addrs and source_addrs
        worker_addrs = [addrs[i*3: i*3 + 3] for i in range(by)]
        addrs = addrs[3*by:]
        for i in range(by):
            d = dict(zip(
                         self.source_names,
                         addrs[i*sources: (i+1)*sources]))
            self.source_addrs[self._worker_id_counter + i] = d
        for x in range(by):
            runner = add_runner(
                worker_id=self._worker_id_counter,
                runners=self.workers,
                command=self.command,
                source_addrs=self.source_addrs,
                sink_addrs=self.sink_addrs,
                metrics_addr=self.metrics_addr,
                control_addr=self.workers[0].control,
                res_dir=self.res_dir,
                workers=by,
                my_control_addr=worker_addrs[x][0],
                my_data_addr=worker_addrs[x][1],
                my_external_addr=worker_addrs[x][2],
                log_rotation=self.log_rotation,
                log_dir=self.log_dir)
            self._worker_id_counter += 1
            runners.append(runner)
            self.runners.append(runner)
        if with_test:
            workers = {'joining': [w.name for w in runners],
                       'leaving': []}
            self.confirm_migration(pre_partitions, workers, timeout=timeout)
        return runners

    def shrink(self, workers=1, timeout=30, with_test=True):
        logging.log(1, "shrink(workers={}, with_test={})".format(
            workers, with_test))
        # pick a worker that's not being shrunk
        if isinstance(workers, basestring):
            snames = set(workers.split(","))
            wnames = set([w.name for w in self.workers])
            complement = wnames - snames # all members of wnames not in snames
            if not complement:
                raise ValueError("Can't shrink all workers!")
            for w in self.workers:
                if w.name in complement:
                    address = w.external
                    break
            leaving = list(filter(lambda w: w.name in snames, self.workers))
        elif isinstance(workers, int):
            if len(self.workers) <= workers:
                raise ValueError("Can't shrink all workers!")
            # choose last workers in `self.workers`
            leaving = self.workers[-workers:]
            address = self.workers[0].external
        else:
            raise ValueError("shrink(workers): workers must be an int or a"
                " comma delimited string of worker names.")
        names = ",".join((w.name for w in leaving))
        pre_partitions = self.get_partition_data() if with_test else None
        # send shrink command to non-shrinking worker
        logging.log(1, "Sending a shrink command for ({})".format(names))
        resp = send_shrink_command(address, names)
        logging.log(1, "Response was: {}".format(resp))
        # no error, so command was successful, update self.workers
        for w in leaving:
            self.workers.remove(w)
        self.dead_workers.extend(leaving)
        if with_test:
            workers = {'leaving': [w.name for w in leaving],
                       'joining': []}
            self.confirm_migration(pre_partitions, workers, timeout=timeout)
        return leaving

    def get_partition_data(self):
        logging.log(1, "get_partition_data()")
        addresses = [(w.name, w.external) for w in self.workers]
        responses = multi_states_query(addresses)
        return coalesce_partition_query_responses(responses)

    def confirm_migration(self, pre_partitions, workers, timeout=120):
        logging.log(1, "confirm_migration(pre_partitions={}, workers={},"
            " timeout={})".format(pre_partitions, workers, timeout))
        def pre_process():
            addresses = [(r.name, r.external) for r in self.workers]
            responses = multi_states_query(addresses)
            post_partitions = coalesce_partition_query_responses(responses)
            return (pre_partitions, post_partitions, workers)
        # retry the test until it passes or a timeout elapses
        logging.log(1, "Running pre_process func with try_until")
        tut = TryUntilTimeout(validate_migration, pre_process,
                              timeout=timeout, interval=2)
        self._stoppables.add(tut)
        tut.start()
        tut.join()
        self._stoppables.discard(tut)
        if tut.error:
            logging.error("validate_partitions failed with inputs:"
                "(pre_partitions: {!r}, post_partitions: {!r}, workers: {!r})"
                .format(*(tut.args if tut.args is not None
                                   else (None, None, None))))
            raise tut.error


    #####################
    # Worker management #
    #####################
    def kill_worker(self, worker=-1):
        """
        Kill a worker, move it from `workers` to `dead_workers`, and return
        it.
        If `worker` is an int, perform this on the Runner instance at `worker`
        position in the `workers` list.
        If `worker` is a Runner instance, perform this on that instance.
        """
        logging.log(1, "kill_worker(worker={})".format(worker))
        if isinstance(worker, Runner):
            # ref to worker
            self.workers.remove(worker)
            r = worker
        else: # index of worker in self.workers
            r = self.workers.pop(worker)
        r.kill()
        self.dead_workers.append(r)
        return r

    def stop_worker(self, worker=-1):
        """
        Stop a worker, move it from `workers` to `dead_workers`, and return
        it.
        If `worker` is an int, perform this on the Runner instance at `worker`
        position in the `workers` list.
        If `worker` is a Runner instance, perform this on that instance.
        """
        logging.log(1, "stop_worker(worker={})".format(worker))
        if isinstance(worker, Runner):
            # ref to worker
            r = self.workers.remove(worker)
        else: # index of worker in self.workers
            r = self.workers.pop(worker)
        r.stop()
        self.dead_workers.append(r)
        return r

    def restart_worker(self, worker=-1):
        """
        Restart a worker(s) via the `respawn` method of a runner, then add the
        new Runner instance to `workers`.
        If `worker` is an int, perform this on the Runner instance at `worker`
        position in the `dead_workers` list.
        If `worker` is a Runner instance, perform this on that instance.
        If `worker` is a list of Runners, perform this on each.
        If `worker` is a slice, perform this on the slice of self.dead_workers
        """
        logging.log(1, "restart_worker(worker={})".format(worker))
        if isinstance(worker, Runner):
            # ref to dead worker instance
            old_rs = [worker]
        elif isinstance(worker, (list, tuple)):
            old_rs = worker
        elif isinstance(worker, slice):
            old_rs = self.dead_workers[worker]
        else: # index of worker in self.dead_workers
            old_rs = [self.dead_workers[worker]]
        new_rs = []
        for r in old_rs:
            new_rs.append(r.respawn())
        for r in new_rs:
            r.start()
        time.sleep(0.05)

        # Wait until all worker processes have started
        new_rs = tuple(new_rs)
        def check_alive():
            [r.is_alive() for r in new_rs]

        tut = TryUntilTimeout(check_alive, timeout=5, interval=0.1)
        self._stoppables.add(tut)
        tut.start()
        tut.join()
        self._stoppables.discard(tut)
        if tut.error:
            logging.error("Bad starters: {}".format(new_rs))
            raise tut.error
        logging.debug("All new runners started successfully")

        for r in new_rs:
            self.restarted_workers.append(r)
            self.workers.append(r)
            self.runners.append(r)
        return new_rs

    def stop_workers(self):
        logging.log(1, "stop_workers()")
        for r in self.runners:
            r.stop()
        # move all live workers to dead_workers
        self.dead_workers.extend(self.workers)
        self.workers = []

    def get_crashed_workers(self,
            func=lambda r: r.poll() not in (None, 0,-9,-15)):
        logging.log(1, "get_crashed_workers()")
        return list(filter(func, self.runners))

    #########
    # Sinks #
    #########
    def stop_sinks(self):
        logging.log(1, "stop_sinks()")
        for s in self.sinks:
            s.stop()

    def sink_await(self, values, timeout=30, func=lambda x: x, sink=-1):
        logging.log(1, "sink_await(values={}, timeout={}, func: {}, sink={})"
            .format(values, timeout, func, sink))
        if isinstance(sink, Sink):
            pass
        else:
            sink = self.sinks[sink]
        t = SinkAwaitValue(sink, values, timeout, func)
        self._stoppables.add(t)
        t.start()
        t.join()
        self._stoppables.discard(t)
        if t.error:
            raise t.error
        logging.debug("sink_await completed successfully")
        return sink

    def sink_expect(self, expected, timeout=30, sink=-1, allow_more=False):
        logging.log(1, "sink_expect(expected={}, timeout={}, sink={})".format(
            expected, timeout, sink))
        if isinstance(sink, Sink):
            pass
        else:
            sink = self.sinks[sink]
        t = SinkExpect(sink, expected, timeout, allow_more=allow_more)
        self._stoppables.add(t)
        t.start()
        t.join()
        self._stoppables.discard(t)
        if t.error:
            raise t.error
        logging.debug("sink_expect completed successfully")
        return sink

    ###########
    # Senders #
    ###########
    def add_sender(self, sender, start=False):
        logging.log(1, "add_sender(sender={}, start={})".format(sender, start))
        self.senders.append(sender)
        if start:
            sender.start()

    def wait_for_sender(self, sender=-1, timeout=30):
        logging.log(1, "wait_for_sender(sender={}, timeout={})"
            .format(sender, timeout))
        if isinstance(sender, (ALOSender, Sender)):
            pass
        else:
            sender = self.senders[sender]
        self._stoppables.add(sender)
        sender.join(timeout)
        self._stoppables.discard(sender)
        if sender.error:
            raise sender.error
        if sender.is_alive():
            raise TimeoutError('Sender did not complete in the expected '
                               'period')

    def stop_senders(self):
        logging.log(1, "stop_senders()")
        for s in self.senders:
            s.stop()

    def pause_senders(self):
        logging.log(1, "pause_senders()")
        for s in self.senders:
            s.pause()
        self.wait_for_senders_to_flush()

    def wait_for_senders_to_flush(self, timeout=30):
        logging.log(1, "wait_for_senders_to_flush({})".format(timeout))
        awaiters = []
        for s in self.senders:
            a = TryUntilTimeout(validate_sender_is_flushed,
                pre_process=(s,),
                timeout=timeout, interval=0.1)
            self._stoppables.add(a)
            awaiters.append(a)
            a.start()
        for a in awaiters:
            a.join()
            self._stoppables.discard(a)
            if a.error:
                raise a.error
            else:
                logging.debug("Sender is fully flushed after pausing.")

    def resume_senders(self):
        logging.log(1, "resume_senders()")
        for s in self.senders:
            s.resume()

    ###########
    # Cluster #
    ###########
    def wait_to_resume_processing(self, timeout=30):
        logging.log(1, "wait_to_resume_processing(timeout={})"
            .format(timeout))
        w = WaitForClusterToResumeProcessing(self.workers, timeout=timeout)
        self._stoppables.add(w)
        w.start()
        w.join()
        self._stoppables.discard(w)
        if w.error:
            raise w.error

    def stop_cluster(self):
        logging.log(1, "stop_cluster()")
        self.stop_senders()
        self.stop_workers()
        self.stop_sinks()

    #########################
    # Observability queries #
    #########################
    def query_observability(self, query, args, tests, timeout=30, period=2):
        logging.log(1, "query_observability(query={}, args={}, tests={}, "
            "timeout={}, period={})".format(
                query, args, tests, timeout, period))
        obs = ObservabilityNotifier(query, args, tests, timeout, period)
        self._stoppables.add(obs)
        obs.start()
        obs.join()
        self._stoppables.discard(obs)
        if obs.error:
            raise obs.error

    ###########################
    # Context Manager functions:
    ###########################
    def __enter__(self):
        return self

    def stop_background_threads(self, error=None):
        logging.log(1, "stop_background_threads({})".format(error))
        for s in self._stoppables:
            s.stop(error)
        self._stoppables.clear()

    def raise_from_error(self, error):
        logging.log(1, "raise_from_error({})".format(error))
        if self._raised:
            return
        self._raised = True
        self.stop_background_threads(error)
        self.__exit__(type(error), error, None)

    def __exit__(self, _type, _value, _traceback):
        logging.log(1, "__exit__({}, {}, {})"
            .format(_type, _value, _traceback))
        if self._exited:
            return
        # clean up any remaining runner processes
        if _type or _value or _traceback:
            logging.error('An error was raised in the Cluster context',
                exc_info=(_type, _value, _traceback))
            self.stop_background_threads(_value)
        else:
            self.stop_background_threads()
        try:
            for w in self.workers:
                w.stop()
            for w in self.dead_workers:
                w.stop()
            # Wait on runners to finish waiting on their subprocesses to exit
            for w in self.runners:
                # Check thread ident to avoid error when joining an un-started
                # thread.
                if w.ident:  # ident is set when a thread is started
                    w.join(self.worker_join_timeout)
            alive = []
            while self.workers:
                w = self.workers.pop()
                if w.is_alive():
                    alive.append(w)
                else:
                    self.dead_workers.append(w)
            if alive:
                alive_names = ', '.join((w.name for w in alive))
                raise ClusterError("Runners [{}] failed to exit cleanly after"
                                   " {} seconds.".format(alive_names,
                                       self.worker_join_timeout))
            # check for workes that exited with a non-0 return code
            # note that workers killed in the previous step have code -15
            bad_exit = []
            for w in self.dead_workers:
                c = w.returncode()
                if c not in (0,-9,-15):  # -9: SIGKILL, -15: SIGTERM
                    bad_exit.append(w)
            if bad_exit:
                raise ClusterError("The following workers terminated with "
                    "a bad exit code: {}"
                    .format(["(name: {}, pid: {}, code:{})".format(
                        w.name, w.pid, w.returncode())
                             for w in bad_exit]))
        finally:
            self.__finally__()
            if self.errors:
                 logging.error("Errors were encountered when running"
                    " the cluster")
                 for e in self.errors:
                     logging.exception(e)
            self._exited = True

    def __finally__(self):
        logging.log(1, "__finally__()")
        self.stop_background_threads()
        if self._finalized:
            return
        logging.info("Doing final cleanup")
        for w in self.runners:
            w.kill()
        for s in self.sinks:
            s.stop()
        for s in self.senders:
            s.stop()
        self.metrics.stop()
        self.persistent_data['runner_data'] = [
            RunnerData(r.name, r.command, r.pid, r.returncode(),
                       r.get_output(), r.start_time)
            for r in self.runners]
        self.persistent_data['sender_data'] = [
            SenderData(s.name, s.host, s.port, s.start_time, s.data)
            for s in self.senders]
        self.persistent_data['sink_data'] = [
            SinkData(s.name, s.host, s.port, s.start_time, s.data)
            for s in self.sinks]
        self.persistent_data['ops'] = self.ops
        clean_resilience_path(self.res_dir)
        ps_cmd = "ps aux"
        ps_out = subprocess.check_output(ps_cmd, stderr=subprocess.STDOUT,
            shell=True)
        logging.debug("procs via {}: {}".format(ps_cmd, ps_out))
        self._finalized = True


def runner_data_format(runner_data, from_tail=0,
                       filter_fn=lambda r: r.returncode not in (0,-9,-15)):
    """
    Format runners' STDOUTs for printing or for inclusion in an error
    - `runners` is a list of Runner instances
    - `from_tail` is the number of lines to keep from the tail of each
      runner's log. The default is to keep the entire log.
    - `filter_fn` is a function to apply to each runner to determine
      whether or not to include its output in the log. The function
      should return `True` if the runner's output is to be included.
      Default is to keep all outputs.
    """
    return '\n===\n'.join(
        ('{identifier} ->\n\n{stdout}'
         '\n\n{identifier} <-'
         .format(identifier="--- {name} (pid: {pid}, rc: {rc})".format(
                    name=rd.name,
                    pid=rd.pid,
                    rc=rd.returncode),
                 stdout='\n'.join(rd.stdout.splitlines()[-from_tail:]))
         for rd in runner_data
         if filter_fn(rd)))
