#!/usr/bin/env bash

# get the root of the directory
REPO_ROOT=$(git rev-parse --show-toplevel)

# ensure that the command below is run from the root of the repository
cd "$REPO_ROOT"

viash ns build --setup cb -q runner

nextflow run . \
  -main-script src/runner/test.nf \
  -entry test \
  -profile docker,local \
  -c src/config/labels.config \
  -resume

nextflow run . \
  -main-script src/runner/test.nf \
  -entry test_multiple_runs \
  -profile docker,local \
  -c src/config/labels.config \
  -resume


nextflow run . \
  -main-script src/runner/test.nf \
  -entry test_empty_channel \
  -profile docker,local \
  -c src/config/labels.config \
  -resume

