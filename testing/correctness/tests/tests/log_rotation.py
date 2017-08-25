# import requisite components for integration test
from integration import (clean_up_resilience_path,
                         ex_validate,
                         get_port_values,
                         Metrics,
                         Reader,
                         Runner,
                         RunnerChecker,
                         RunnerReadyChecker,
                         Sender,
                         sequence_generator,
                         setup_resilience_path,
                         Sink,
                         SinkAwaitValue,
                         start_runners,
                         TimeoutError)
import os
import re
import time
import struct


log_rotated_patterns = ['Starting event log rotation\.',
            '~~~Stopping message processing for log rotation\.~~~',
            'Snapshotting \d+ steps to new log file\.',
            'Steps snapshotting to new log file complete\.',
            '~~~Resuming message processing\.~~~']
log_rotated_pattern = '.*'.join(log_rotated_patterns)


def test_log_rotation_external_trigger_no_recovery():
    host = '127.0.0.1'
    sources = 1
    workers = 2
    res_dir = '/tmp/res-data'
    expect = 2000
    last_value = '[{}]'.format(','.join((str(expect-v)
                                         for v in range(6,-2,-2))))
    await_value = struct.pack('>I', len(last_value)) + last_value

    setup_resilience_path(res_dir)

    command = 'sequence_window_resilience --log-rotation'

    runners = []
    try:
        # Create sink, metrics, reader, sender
        sink = Sink(host)
        metrics = Metrics(host)
        reader = Reader(sequence_generator(expect))

        # Start sink and metrics, and get their connection info
        sink.start()
        sink_host, sink_port = sink.get_connection_info()
        outputs = '{}:{}'.format(sink_host, sink_port)

        metrics.start()
        metrics_host, metrics_port = metrics.get_connection_info()
        time.sleep(0.05)

        input_ports, control_port, external_port, data_port = (
            get_port_values(host, sources))
        inputs = ','.join(['{}:{}'.format(host, p) for p in
                           input_ports])

        start_runners(runners, command, host, inputs, outputs,
                      metrics_port, control_port, external_port, data_port,
                      res_dir, workers)

        # Wait for first runner (initializer) to report application ready
        runner_ready_checker = RunnerReadyChecker(runners[0], timeout=30)
        runner_ready_checker.start()
        runner_ready_checker.join()
        if runner_ready_checker.error:
            raise runner_ready_checker.error

        # start sender
        sender = Sender(host, input_ports[0], reader, batch_size=100,
                        interval=0.05)
        sender.start()

        time.sleep(0.5)
        # Trigger log rotation with external message
        cmd_external_trigger = ('external_sender -e {}:{} -t rotate-log -m '
                                'worker1'
                                .format(host, external_port))

        success, stdout, retcode, cmd = ex_validate(cmd_external_trigger)
        try:
            assert(success)
        except AssertionError:
            raise AssertionError('External rotation trigger failed with '
                                 'the error:\n{}'.format(stdout))

        # wait until sender completes (~1 second)
        sender.join(30)
        if sender.error:
            raise sender.error
        if sender.is_alive():
            sender.stop()
            raise TimeoutError('Sender did not complete in the expected '
                               'period')

        # Use metrics to determine when to stop runners and sink
        stopper = SinkAwaitValue(sink, await_value, 30)
        stopper.start()
        stopper.join()
        if stopper.error:
            for r in runners:
                print r.name
                print r.get_output()[0]
                print '---'
            print 'sink data'
            print sink.data
            print '---'
            raise stopper.error

        # stop application workers
        for r in runners:
            r.stop()

        # Stop sink
        sink.stop()
        print 'sink.data size: ', len(sink.data)


        # Use validator to validate the data in at-least-once mode
        # save sink data to a file
        out_file = os.path.join(res_dir, 'received.txt')
        sink.save(out_file, mode='giles')

        # Validate captured output
        cmd_validate = ('validator -i {out_file} -e {expect} -a'
                        .format(out_file = out_file,
                                expect = expect))
        success, stdout, retcode, cmd = ex_validate(cmd_validate)
        try:
            assert(success)
        except AssertionError:
            print runners[0].get_output()[0]
            print '---'
            print runners[1].get_output()[0]
            print '---'
            raise AssertionError('Validation failed with the following '
                                 'error:\n{}'.format(stdout))

        # Validate all workers underwent log rotation
        for r in runners[1:]:
            stdout, stderr = r.get_output()
            try:
                assert(re.search(log_rotated_pattern, stdout, re.M | re.S)
                       is not None)
            except AssertionError:
                raise AssertionError('Worker %r does not appear to have '
                                     'performed log rotation as expected.'
                                     ' The pattern %r '
                                     'is missing form the Worker output '
                                     'included below.\nSTDOUT\n---\n%s\n'
                                     '---\n'
                                     % (r.name, log_rotated_pattern, stdout))
    finally:
        for r in runners:
            r.stop()
        clean_up_resilience_path(res_dir)


def test_log_rotation_external_trigger_recovery():
    host = '127.0.0.1'
    sources = 1
    workers = 2
    res_dir = '/tmp/res-data'
    expect = 2000
    last_value = '[{}]'.format(','.join((str(expect-v)
                                         for v in range(6,-2,-2))))
    await_value = struct.pack('>I', len(last_value)) + last_value

    setup_resilience_path(res_dir)

    command = 'sequence_window_resilience --log-rotation'

    runners = []
    try:
        # Create sink, metrics, reader, sender
        sink = Sink(host)
        metrics = Metrics(host)
        reader = Reader(sequence_generator(expect))

        # Start sink and metrics, and get their connection info
        sink.start()
        sink_host, sink_port = sink.get_connection_info()
        outputs = '{}:{}'.format(sink_host, sink_port)

        metrics.start()
        metrics_host, metrics_port = metrics.get_connection_info()
        time.sleep(0.05)

        input_ports, control_port, external_port, data_port = (
            get_port_values(host, sources))
        inputs = ','.join(['{}:{}'.format(host, p) for p in
                           input_ports])

        start_runners(runners, command, host, inputs, outputs,
                      metrics_port, control_port, external_port, data_port,
                      res_dir, workers)

        # Wait for first runner (initializer) to report application ready
        runner_ready_checker = RunnerReadyChecker(runners[0], timeout=30)
        runner_ready_checker.start()
        runner_ready_checker.join()
        if runner_ready_checker.error:
            raise runner_ready_checker.error

        # start sender
        sender = Sender(host, input_ports[0], reader, batch_size=100,
                        interval=0.05)
        sender.start()

        time.sleep(0.5)
        # Trigger log rotation with external message
        cmd_external_trigger = ('external_sender -e {}:{} -t rotate-log -m '
                                'worker1'
                                .format(host, external_port))

        success, stdout, retcode, cmd = ex_validate(cmd_external_trigger)
        try:
            assert(success)
        except AssertionError:
            raise AssertionError('External rotation trigger failed with '
                                 'the error:\n{}'.format(stdout))

        # Check for log rotation
        log_rotated_checker = RunnerChecker(runners[1], log_rotated_patterns,
                                            timeout=30)
        log_rotated_checker.start()
        log_rotated_checker.join()
        if log_rotated_checker.error:
            raise log_rotated_checker.error

        # stop worker
        runners[-1].stop()

        ## restart worker
        runners.append(runners[-1].respawn())
        runners[-1].start()

        # wait until sender completes (~1 second)
        sender.join(30)
        if sender.error:
            raise sender.error
        if sender.is_alive():
            sender.stop()
            raise TimeoutError('Sender did not complete in the expected '
                               'period')

        # Use metrics to determine when to stop runners and sink
        stopper = SinkAwaitValue(sink, await_value, 30)
        stopper.start()
        stopper.join()
        if stopper.error:
            for r in runners:
                print r.name
                print r.get_output()[0]
                print '---'
            print 'sink data'
            print sink.data
            print '---'
            raise stopper.error

        # stop application workers
        for r in runners:
            r.stop()

        # Stop sink
        sink.stop()
        print 'sink.data size: ', len(sink.data)


        # Use validator to validate the data in at-least-once mode
        # save sink data to a file
        out_file = os.path.join(res_dir, 'received.txt')
        sink.save(out_file, mode='giles')

        # Validate captured output
        cmd_validate = ('validator -i {out_file} -e {expect} -a'
                        .format(out_file = out_file,
                                expect = expect))
        success, stdout, retcode, cmd = ex_validate(cmd_validate)
        try:
            assert(success)
        except AssertionError:
            print runners[0].get_output()[0]
            print '---'
            print runners[1].get_output()[0]
            print '---'
            raise AssertionError('Validation failed with the following '
                                 'error:\n{}'.format(stdout))

        # Validate all workers underwent log rotation
        r = runners[1]
        stdout, stderr = r.get_output()
        try:
            assert(re.search(log_rotated_pattern, stdout, re.M | re.S)
                   is not None)
        except AssertionError:
            raise AssertionError('Worker %d.%r does not appear to have '
                                 'performed log rotation as expected.'
                                 ' The pattern %r '
                                 'is missing form the Worker output '
                                 'included below.\nSTDOUT\n---\n%s\n'
                                 '---\n'
                                 % (1, r.name, log_rotated_pattern, stdout))
        # Validate worker actually underwent recovery
        pattern = "RESILIENCE\: Replayed \d+ entries from recovery log file\."
        stdout, stderr = runners[-1].get_output()
        try:
            assert(re.search(pattern, stdout) is not None)
        except AssertionError:
            raise AssertionError('Worker %d.%r does not appear to have '
                                 'performed recovery as expected. Worker '
                                 'output is '
                                 'included below.\nSTDOUT\n---\n%s\n---\n'
                                 'STDERR\n---\n%s'
                                 % (len(runners)-1, runners[-1].name,
                                    stdout, stderr))
    finally:
        for r in runners:
            r.stop()
        clean_up_resilience_path(res_dir)


def test_log_rotation_file_size_trigger_no_recovery():
    host = '127.0.0.1'
    sources = 1
    workers = 2
    res_dir = '/tmp/res-data'
    expect = 2000
    event_log_file_size = 50000
    last_value = '[{}]'.format(','.join((str(expect-v) for v in range(6,-2,-2))))
    await_value = struct.pack('>I', len(last_value)) + last_value

    setup_resilience_path(res_dir)

    command = ('sequence_window_resilience --log-rotation --event-log-file-size {}'
               .format(event_log_file_size))

    runners = []
    try:
        # Create sink, metrics, reader, sender
        sink = Sink(host)
        metrics = Metrics(host)
        reader = Reader(sequence_generator(expect))

        # Start sink and metrics, and get their connection info
        sink.start()
        sink_host, sink_port = sink.get_connection_info()
        outputs = '{}:{}'.format(sink_host, sink_port)

        metrics.start()
        metrics_host, metrics_port = metrics.get_connection_info()
        time.sleep(0.05)

        input_ports, control_port, external_port, data_port = (
            get_port_values(host, sources))
        inputs = ','.join(['{}:{}'.format(host, p) for p in
                           input_ports])

        start_runners(runners, command, host, inputs, outputs,
                      metrics_port, control_port, external_port, data_port,
                      res_dir, workers)

        # Wait for first runner (initializer) to report application ready
        runner_ready_checker = RunnerReadyChecker(runners[0], timeout=30)
        runner_ready_checker.start()
        runner_ready_checker.join()
        if runner_ready_checker.error:
            raise runner_ready_checker.error

        # start sender
        sender = Sender(host, input_ports[0], reader, batch_size=100,
                        interval=0.05)
        sender.start()



        # wait until sender completes (~1 second)
        sender.join(30)
        if sender.error:
            raise sender.error
        if sender.is_alive():
            sender.stop()
            raise TimeoutError('Sender did not complete in the expected '
                               'period')

        # Use metrics to determine when to stop runners and sink
        stopper = SinkAwaitValue(sink, await_value, 30)
        stopper.start()
        stopper.join()
        if stopper.error:
            for r in runners:
                print r.name
                print r.get_output()[0]
                print '---'
            print 'sink data'
            print sink.data
            print '---'
            raise stopper.error

        # stop application workers
        for r in runners:
            r.stop()

        # Stop sink
        sink.stop()
        print 'sink.data size: ', len(sink.data)

        # Use validator to validate the data in at-least-once mode
        # save sink data to a file
        out_file = os.path.join(res_dir, 'received.txt')
        sink.save(out_file, mode='giles')

        # Validate captured output
        cmd_validate = ('validator -i {out_file} -e {expect} -a'
                        .format(out_file = out_file,
                                expect = expect))
        success, stdout, retcode, cmd = ex_validate(cmd_validate)
        try:
            assert(success)
        except AssertionError:
            print runners[0].get_output()[0]
            print '---'
            print runners[1].get_output()[0]
            print '---'
            raise AssertionError('Validation failed with the following '
                                 'error:\n{}'.format(stdout))

        # Validate all workers underwent log rotation
        for r in runners:
            stdout, stderr = r.get_output()
            try:
                assert(re.search(log_rotated_pattern, stdout, re.M | re.S)
                       is not None)
            except AssertionError:
                raise AssertionError('Worker %r does not appear to have '
                                     'performed log rotation as expected.'
                                     ' The pattern %r '
                                     'is missing form the Worker output '
                                     'included below.\nSTDOUT\n---\n%s\n'
                                     '---\n'
                                     % (r.name, log_rotated_pattern, stdout))
    finally:
        for r in runners:
            r.stop()
        clean_up_resilience_path(res_dir)


def test_log_rotation_file_size_trigger_recovery():
    host = '127.0.0.1'
    sources = 1
    workers = 2
    res_dir = '/tmp/res-data'
    expect = 2000
    event_log_file_size = 50000
    last_value = '[{}]'.format(','.join((str(expect-v)
                                         for v in range(6,-2,-2))))
    await_value = struct.pack('>I', len(last_value)) + last_value

    setup_resilience_path(res_dir)

    command = ('sequence_window_resilience --log-rotation '
               '--event-log-file-size {}'
               .format(event_log_file_size))

    runners = []
    try:
        # Create sink, metrics, reader, sender
        sink = Sink(host)
        metrics = Metrics(host)
        reader = Reader(sequence_generator(expect))

        # Start sink and metrics, and get their connection info
        sink.start()
        sink_host, sink_port = sink.get_connection_info()
        outputs = '{}:{}'.format(sink_host, sink_port)

        metrics.start()
        metrics_host, metrics_port = metrics.get_connection_info()
        time.sleep(0.05)

        input_ports, control_port, external_port, data_port = (
            get_port_values(host, sources))
        inputs = ','.join(['{}:{}'.format(host, p) for p in
                           input_ports])

        start_runners(runners, command, host, inputs, outputs,
                      metrics_port, control_port, external_port, data_port,
                      res_dir, workers)

        # Wait for first runner (initializer) to report application ready
        runner_ready_checker = RunnerReadyChecker(runners[0], timeout=30)
        runner_ready_checker.start()
        runner_ready_checker.join()
        if runner_ready_checker.error:
            raise runner_ready_checker.error

        # start sender
        sender = Sender(host, input_ports[0], reader, batch_size=100,
                        interval=0.05)
        sender.start()

        # Wait for runner to complete a log rotation
        log_rotated_checker = RunnerChecker(runners[1], log_rotated_patterns,
                                            timeout=30)
        log_rotated_checker.start()
        log_rotated_checker.join()
        if log_rotated_checker.error:
            raise log_rotated_checker.error

        # stop worker
        runners[-1].stop()

        ## restart worker
        runners.append(runners[-1].respawn())
        runners[-1].start()

        # wait until sender completes (~1 second)
        sender.join(30)
        if sender.error:
            raise sender.error
        if sender.is_alive():
            sender.stop()
            raise TimeoutError('Sender did not complete in the expected '
                               'period')

        # Use metrics to determine when to stop runners and sink
        stopper = SinkAwaitValue(sink, await_value, 30)
        stopper.start()
        stopper.join()
        if stopper.error:
            for r in runners:
                print r.name
                print r.get_output()[0]
                print '---'
            print 'sink data'
            print sink.data
            print '---'
            raise stopper.error

        # stop application workers
        for r in runners:
            r.stop()

        # Stop sink
        sink.stop()
        print 'sink.data size: ', len(sink.data)

        # Use validator to validate the data in at-least-once mode
        # save sink data to a file
        out_file = os.path.join(res_dir, 'received.txt')
        sink.save(out_file, mode='giles')

        # Validate captured output
        cmd_validate = ('validator -i {out_file} -e {expect} -a'
                        .format(out_file = out_file,
                                expect = expect))
        success, stdout, retcode, cmd = ex_validate(cmd_validate)
        try:
            assert(success)
        except AssertionError:
            print runners[-1].get_output()[0]
            print '---'
            print runners[-2].get_output()[0]
            print '---'
            raise AssertionError('Validation failed with the following '
                                 'error:\n{}'.format(stdout))

        # Validate all workers underwent log rotation
        for (i, r) in enumerate(runners[:-1]):
            stdout, stderr = r.get_output()
            try:
                assert(re.search(log_rotated_pattern, stdout, re.M | re.S)
                       is not None)
            except AssertionError:
                raise AssertionError('Worker %d.%r does not appear to have '
                                     'performed log rotation as expected.'
                                     ' The pattern %r '
                                     'is missing form the Worker output '
                                     'included below.\nSTDOUT\n---\n%s\n'
                                     '---\n'
                                     % (i, r.name, log_rotated_pattern,
                                        stdout))

        # Validate worker actually underwent recovery
        pattern = "RESILIENCE\: Replayed \d+ entries from recovery log file\."
        stdout, stderr = runners[-1].get_output()
        try:
            assert(re.search(pattern, stdout) is not None)
        except AssertionError:
            raise AssertionError('Worker does not appear to have performed '
                                 'recovery as expected. Worker output is '
                                 'included below.\nSTDOUT\n---\n%s\n---\n'
                                 'STDERR\n---\n%s' % (stdout, stderr))
    finally:
        for r in runners:
            r.stop()
        clean_up_resilience_path(res_dir)
