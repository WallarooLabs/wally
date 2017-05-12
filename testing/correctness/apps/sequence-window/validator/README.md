# Validator

Validator validates the output of a sequence-window run, as recorded by giles-receiver.
It handles decoding the output file and performs the following tests:
1. For each observed window, test:
  1. size == 4
  2. no non-leading zeroes are present (and at least one value is non-zero)
  3. all non-zero values have the same parity
  4. Values in a window increment as expected (by 0,1, or 2, and always by 2
    after a non-zero increment)
  5. sequentiality: the current window follows from the previous window
    (e.g. [4,6,8,10] follows [2,4,6,8])

2. For the two final windows, test:
  1. the highest value matches the `--expected/-e` value
  2. the highet value in the non-highest-value window is exactly 1 less than
    the `--expected/-e` value.

## Running Validator

Validator takes 3 command line options:
1. `--input/-i`: the file path to validate
2. `--expect/-e`: total number of values to expect at the end (default 1000)
3. `--at-least-once/-a`: run the test in at-least-once mode instead of exactly-once.

## Testing the validator

In the `examples` directory there is a `data_gen.py` script that will generate a sample input file for each case. Each file is named according to the expected outcome (pass, fail_expect_max, etc).

Run the script to generate the test files:

```bash
cd examples
python data_gen.py
```

Then run the validator with the appropriate options for each test:

```bash
# Passing
./validator -i examples/pass.txt
./validator -i examples/pass_with_atleastonce.txt -a
./validator -i examples/fail_expect_max.txt -e 1002

# Failing
./validator -i examples/fail_expected_difference.txt
./validator -i examples/fail_expect_max.txt
./validator -i examples/fail_increments.txt
./validator -i examples/fail_no_nonlead_zeroes.txt
./validator -i examples/fail_parity.txt
./validator -i examples/fail_sequentiality.txt
./validator -i examples/fail_size.txt
./validator -i examples/pass_with_atleastonce.txt
```
