#!/usr/bin/env bash

# get the root of the directory
REPO_ROOT=$(git rev-parse --show-toplevel)

# ensure that the command below is run from the root of the repository
cd "$REPO_ROOT"

viash ns build --setup cb

nextflow run . \
  -main-script src/demultiplex/test.nf \
  -profile docker,no_publish \
  -entry test_wf \
  -c src/config/tests.config \
  -resume
