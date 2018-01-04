#! /bin/bash

set -o errexit
set -o nounset

# Run the correctness tests that require a resilience build
make integration-tests-testing-correctness-tests-all resilience=on debug=true
