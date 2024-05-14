#!/usr/bin/env bash

set -eo pipefail

if [ ! -d "$par_input" ]; then
    echo "Input directory does not exist or is not a directory"
    exit 1
fi
$(which summary) --csv=1 "$par_input" 1> "$par_output_run_summary"
$(which index-summary) --csv=1 "$par_input" 1> "$par_output_index_summary"
