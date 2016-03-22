# Wesley

Validation the results of tests run by Giles.

"Wesley is ... an irritating foil for ... Rupert Giles."

Ver 0.0.1-sendence

## Validation

Wesley does the following:
1. applies a transforming function to the messages sent by Giles to
   Buffy to produce expected results
1. compares the expected results to the actual messages that Giles
   receives from Buffy
1. compares whether the expected results and actual results were
   supposed to match

There are a few things that are important to note:
* There may not be a 1-to-1 mapping of sent messages and expected
  results. For example, a topology may only send a messages when it
  has received several messages with different pieces of related
  information.
* The comparison between the actual match result and the expected
  match result is necessary because Buffy may not yet have implemented
  the functionality for correcting certain types of errors.

## The Idea

Giles sends messages `S` to Buffy, which processes those messages and
produces the received message `R`.

```
Giles =S=> Buffy =R=> Giles

  S: the ordered list of sent messages
  R: the ordered list of received messages
```

There is a function `f(x)` which transforms S into the expected
received messages, `Re`.

```
Re = f(S)
```

There is an equality function `e(x, y)` which tells us if `R` and `Re`
are equal or not.

```
e(R, Re) = equal | notEqual
```

For any given test configuration there will be an expectation that the
result of the equality function will either be equal or notEqual. This
is specified within the test configuration. The validation function
`v(x, y)` passes if the expectation is the same as the result of `e(R,
Re)`, otherwise it fails.

```
v(e(R, Re), expectation) = pass | fail
```

The test system expands to:

```
v(e(R, f(S)), expectation)
```

The only piece that needs to change from topology to topology is the
function `f(x)`.

## In Practice

Giles runs a test based on a configuration (nodes in Buffy with
intervening Spike nodes which modify the messages passing through the
system in some way), and records the sent messages (`sent.txt`) and
received messages (`received.txt`) once the test finishes. After the
test has run, Wesley takes the sent messages, applies the
transformation function to them, and compares the expected received
messages to the actual received messages, then compares this outcome
with the expected outcome.

Each Wesley validator is a stand-alone executable. The source for the
program is stored under the `wesley` directory and includes only code
that is specific to the topoloy under test (objects for reading
messages and the transformation function `f(S) => Re`).

Wesley validation is run like this:

```VALIDATION-EXECUTABLE SENT-FILE RECEIVED-FILE [match|nomatch|CONFIG-INI-FILE]```

For example, this command verifies the outcome of an `identity` test
where the expected received messages and actual received messages are
supposed to be equal:

```./wesley/identity/identity ./giles/sent.txt ./giles/received.txt match```

This command verifies the outcome of a `double` test where the
expected match status of the expected received messages and actual
received messages is specified in an ini file called `double.ini`:

```./wesley/double/double ./giles/sent.txt ./giles/received.txt ./dagon/config/double.ini```

After a test runs it will print a message stating the expected match
status and the actual match status; if they are the same the exit code
will 0, otherwise it will be 1.