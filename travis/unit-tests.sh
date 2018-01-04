#! /bin/bash

set -o errexit
set -o nounset

# Verify that EVERYTHING builds even if it doesn't have unit tests
make build debug=true
# Validate that unit tests are passing
make unit-tests debug=true


