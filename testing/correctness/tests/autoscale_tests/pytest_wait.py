import pytest

def pause_for_user():

    # suspend input capture by py.test so user input can be recorded here
    capture_manager = pytest.config.pluginmanager.getplugin('capturemanager')
    capture_manager.suspendcapture(in_=True)

    answer = raw_input("Press Return to continue\n")

    # resume capture after question have been asked
    capture_manager.resumecapture()
