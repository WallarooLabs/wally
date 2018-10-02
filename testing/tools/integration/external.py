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
import logging
import os
import re
import shlex
import shutil
import socket
import subprocess


ShellCmdResult = namedtuple('ShellCmdResult',
                            ('success', 'output', 'return_code', 'command'))


def run_shell_cmd(cmd):
    """
    Run a shell command, wait for it to exit.
    Return the tuple (Success (bool), output, return_code, command).
    """
    try:
        out = subprocess.check_output(shlex.split(cmd),
                                      stderr=subprocess.STDOUT)
    except subprocess.CalledProcessError as err:
        return ShellCmdResult(False, err.output, err.returncode, err.cmd)
    except OSError as err:
        if err.errno == 2:  # no such file or directory
            return ShellCmdResult(False, str(err), 2, cmd)
        else:
            raise
    return ShellCmdResult(True, out, 0, shlex.split(cmd))


def setup_resilience_path(res_dir):
    # create resilience data directory if it doesn't already exist
    if not os.path.exists(res_dir):
        create_resilience_dir(res_dir)
    for f in os.listdir(res_dir):
        path = os.path.join(res_dir, f)
        try:
            os.remove(path)
        except Exception as e:
            logging.warning('Warning: remove %s failed: %s' % (path, e))


def create_resilience_dir(res_dir):
    try:
        os.mkdir(res_dir)
    except Exception as e:
        logging.exception('Warning: mkdir %s failed: %s' % (res_dir, e))


def clean_resilience_path(res_dir):
    try:
        os.environ['KEEP_RESILIENCE_PATH']
        delete = False
    except:
        delete = True
    if delete and os.path.exists(res_dir):
        shutil.rmtree(res_dir, True)


def is_address_available(host, port):
    """
    Test whether a (host, port) pair is free
    """
    try:
        s = socket.socket()
        s.bind((host, port))
        s.close()
        return True
    except:
        return False


def get_port_values(num=1, host='127.0.0.1', base_port=20000):
    """
    Get the requested number (default: 1) of free ports for a given host
    (default: '127.0.0.1'), starting from base_port (default: 20000).
    """

    ports = []

    # Select source listener ports
    while len(ports) < num:
        if is_address_available(host, base_port):
            ports.append(base_port)
        base_port += 1
    return ports


def send_shrink_command(addr, workers):
    # Trigger log rotation with external message
    cmd_external_trigger = ('cluster_shrinker --external {} --workers {}'
                            .format(addr, workers))

    res = run_shell_cmd(cmd_external_trigger)
    try:
        assert(res.success)
    except AssertionError:
        raise AssertionError('External shrink trigger failed with '
                             'the error:\n{}'.format(res))
    return res.output


def makedirs_if_not_exists(dirpath):
    """
    Recursively create a directory path.

    If path already exists return None.
    Errors in path creation _other_ than path already existing will raise.
    """
    try:
        os.makedirs(dirpath)
    except OSError:
        if not os.path.isdir(dirpath):
            raise


def save_logs_to_file(base_dir, log_stream=None, persistent_data={}):
    """
    Save logs to individual files.

    `base_dir` is the base directory relative to the current working directory
    in which to save the files. It will be created recursively if it does not
    already exist.
    `log_stream` is a StringIO log_stream containing logs captured with
    the logging module.
    `runner_data` is a collection of `RunnerData` instances returned by
    a Cluster context.
    """
    try:
        makedirs_if_not_exists(base_dir)
        if log_stream:
            with open(os.path.join(base_dir, 'test.error.log'), 'wb') as f:
                f.write(log_stream.getvalue())
        runner_data = persistent_data.get('runner_data', [])

        # save worker data to files
        for rd in runner_data:
            worker_log_name = '{name}.{pid}.{code}.{time}.error.log'.format(
                name=rd.name,
                code=rd.returncode,
                pid=rd.pid,
                time=rd.start_time.strftime('%Y%m%d_%H%M%S.%f'))
            with open(os.path.join(base_dir, worker_log_name), 'wb') as f:
                f.write('{identifier} ->\n\n{stdout}\n\n{identifier} <-'
                    .format(identifier="--- {name} (pid: {pid}, rc: {rc})"
                        .format(name=rd.name, pid=rd.pid,
                                rc=rd.returncode),
                            stdout=rd.stdout))

        # save sender data to files
        sender_data = persistent_data.get('sender_data', [])
        for sd in sender_data:
            sender_log_name = 'sender_{address}_{time}.error.dat'.format(
                address=sd.address.replace(':', '.'),
                time=sd.start_time.strftime('%Y%m%d_%H%M%S.%f'))
            with open(os.path.join(base_dir, sender_log_name), 'wb') as f:
                f.write(''.join(sd.data))

        # save sinks data to files
        sink_data = persistent_data.get('sink_data', [])
        for sk in sink_data:
            sink_log_name = 'sink_{address}_{time}.error.dat'.format(
                address=sk.address.replace(':', '.'),
                time=sk.start_time.strftime('%Y%m%d_%H%M%S.%f'))
            with open(os.path.join(base_dir, sink_log_name), 'wb') as f:
                f.write(''.join(sk.data))
        logging.warn("Error logs saved to {}".format(base_dir))

        # save core files if they exist
        rex = re.compile('core.*')
        cores = filter(lambda s: rex.match(s), os.listdir(os.getcwd()))
        if cores:
            logging.warn("Core files detected: {}".format(cores))
        for core in cores:
            logging.info("Moving core {} to {}".format(core, base_dir))
            shutil.move(core, os.path.join(base_dir, core))
    except Exception as err:
        logging.error("Failed to write failure log files.")
        logging.exception(err)
