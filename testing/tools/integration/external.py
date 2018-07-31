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
