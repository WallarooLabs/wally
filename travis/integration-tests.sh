#! /bin/bash

set -o errexit
set -o nounset

# Run our non-resilience integration tests
make integration-tests debug=true
