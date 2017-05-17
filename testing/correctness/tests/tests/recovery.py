def test_recovery():
    # import requisite components for integration test
    from integration import (clean_up_resilience_path,
                             ex_validate,
                             get_port_values,
                             Metrics,
                             Reader,
                             Runner,
                             RunnerReadyChecker,
                             Sender,
                             sequence_generator,
                             setup_resilience_path,
                             Sink,
                             SinkStopper,
                             start_runners,
                             TimeoutError)
    import os
    import re
    import time

    host = '127.0.0.1'
    sources = 1
    workers = 2
    res_dir = '/tmp/res-data'
    expect = 2000

    setup_resilience_path(res_dir)

    command = '''
        sequence_window \
          --resilience-dir {res_dir}
        '''.format(res_dir = res_dir)

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

        input_ports, control_port, data_port = (
            get_port_values(host, sources))
        inputs = ','.join(['{}:{}'.format(host, p) for p in
                           input_ports])

        start_runners(runners, command, host, inputs, outputs,
                      metrics_port, control_port, data_port, workers)

        # Wait for first runner (initializer) to report application ready
        runner_ready_checker = RunnerReadyChecker(runners[0], 5)
        runner_ready_checker.start()
        runner_ready_checker.join()
        if runner_ready_checker.error:
            raise runner_ready_checker.error

        # start sender
        sender = Sender(host, input_ports[0], reader, batch_size=100,
                        interval=0.05)
        sender.start()
        time.sleep(0.2)

        # stop worker
        runners[-1].stop()

        ## restart worker
        runners.append(runners[-1].respawn())
        runners[-1].start()


        # wait until sender completes (~1 second)
        sender.join(5)
        if sender.error:
            raise sender.error
        if sender.is_alive():
            sender.stop()
            raise TimeoutError('Sender did not complete in the expected '
                               'period')

        # Use metrics to determine when to stop runners and sink
        stopper = SinkStopper(sink, expect)
        stopper.start()
        stopper.join()
        if stopper.error:
            raise stopper.error

        # stop application workers
        for r in runners:
            r.stop()

        # Stop sink
        sink.stop()

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
            raise AssertionError('Validation failed with the following '
                                 'error:\n{}'.format(stdout))

        # Validate worker actually underwent recovery
        pattern = "RESILIENCE\: Replayed \d+ entries from recovery log file\."
        stdout, stderr = runners[-1].get_output()
        try:
            assert(re.search(pattern, stdout) is not
                   None)
        except AssertionError:
            raise AssertionError('Worker does not appear to have performed '
                                 'recovery as expected. Worker output is '
                                 'included below.\nSTDOUT\n---\n%s\n---\n'
                                 'STDERR\n---\n%s' % (stdout, stderr))
    finally:
        for r in runners:
            r.stop()
        clean_up_resilience_path(res_dir)
