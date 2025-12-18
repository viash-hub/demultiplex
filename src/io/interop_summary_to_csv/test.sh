#!/usr/bin/env bash

set -eo pipefail

# create tempdir
echo ">>> Creating temporary test directory."
TMPDIR=$(mktemp -d "$meta_temp_dir/$meta_functionality_name-XXXXXX")
function clean_up {
  [[ -d "$TMPDIR" ]] && rm -r "$TMPDIR"
}
trap clean_up EXIT
echo ">>> Created temporary directory '$TMPDIR'."

echo ">>> Run simple execution"
./$meta_functionality_name \
   --input "$meta_resources_dir/SingleCell-RNA_P3_2" \
   --output_run_summary "$TMPDIR/run_summary.csv" \
   --output_index_summary "$TMPDIR/index_summary.csv"