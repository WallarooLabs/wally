#! /bin/bash

set -o errexit
set -o nounset

make test debug=true
# Make sure to run `make clean` between separate test runs to clear any conflicting dependencies
make clean
# Run the correctness tests that require a resilience build
make integration-tests-testing-correctness-tests-all resilience=on debug=true
