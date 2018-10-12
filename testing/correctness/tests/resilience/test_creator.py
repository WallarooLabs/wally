from resilience import _test_resilience

class Creator(object):
    def __init__(self, module):
        self.module = module

    def create(self, test_name_fmt, api, cmd, ops, cycles=1, initial=None,
                    validate_output=True, sources=1):
        test_name = test_name_fmt.format(api=api,
                                         ops='_'.join((o.name().replace(':','')
                                                       for o in ops*cycles)))
        def f():
            _test_resilience(cmd, ops=ops, cycles=cycles, initial=initial,
                             validate_output=validate_output, sources=sources)
        f.func_name = test_name
        setattr(self.module, test_name, f)
