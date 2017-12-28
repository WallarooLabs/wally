#! /bin/bash

set -o errexit
set -o nounset

make test debug=true
# Make sure to run `make clean` between separate test runs to clear any conflicting dependencies
make clean

if [[ "$TRAVIS_BRANCH" == "release" ]]
then
	echo "Skipping correctness tests on release branch..."
	exit 0
else
	# Run the correctness tests that require a resilience build
	make integration-tests-testing-correctness-tests-all resilience=on debug=true
fi
