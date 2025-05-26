#!/usr/bin/env bash

set -eo pipefail

# get the root of the directory
REPO_ROOT=$(git rev-parse --show-toplevel)

# ensure that the command below is run from the root of the repository
cd "$REPO_ROOT"

viash ns build --setup cb -q gather_fastqs_and_validate

nextflow run . \
  -main-script src/dataflow/gather_fastqs_and_validate/test.nf \
  -profile docker,no_publish,local \
  -entry test_gather_and_validate \
  -c src/config/labels.config \
  -resume

nextflow run . \
  -main-script src/dataflow/gather_fastqs_and_validate/test.nf \
  -profile docker,no_publish,local \
  -entry test_undetermined_empty \
  -c src/config/labels.config \
  -resume

nextflow run . \
  -main-script src/dataflow/gather_fastqs_and_validate/test.nf \
  -profile docker,no_publish,local \
  -entry test_without_index \
  -c src/config/labels.config \
  -resume

