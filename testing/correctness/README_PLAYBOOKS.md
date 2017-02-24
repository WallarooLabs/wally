# Correctness Testing Playbooks
A test playbook is a step-by-step instruction on how to reproduce a certain test, along with a description of the purpose of the test and ancillary information, as well as expected and observed behaviours.
These playbooks may be written in plain english, psuedo code, or any combination. They are each intended as a rough sketch for designing an automated test, which will pass when the observed behaviour matches the expected behaviour.

Steps in the test include things such as commands to execute and the order in which to execute them, as well as objects of observation (e.g. "you should check the application console printout for the following values…").


Once a playbook is succeeded by an automated test, the purpose, description, and expectation should be included in the docstring. If the code is complex and there are key steps, they should be described in the docstring as well.

Note that simpler/shorter tests with fewer steps are easier to execute reliably, and will be easier to automate, so whenever possible, it is worth spending the time to reduce a test to the minimal or near-minimal sequence required for exercising a subject.
