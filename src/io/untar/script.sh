#!/usr/bin/env bash

set -eo pipefail

extra_args=()

# Check if tarball contains 1 top-level directory. If so, extract the contents of the
# directory to the output directory instead of the directory itself.
echo "Directory contents:"
tar -taf "${par_input}" > tar_contents.txt
cat tar_contents.txt

printf "Checking if tarball contains only a single top-level directory: "
if [[ $(cat tar_contents | grep -o -E "^[./]*[^/]+/$" | uniq | wc -l) -eq 1 ]]; then
    echo "It does."
    echo "Extracting the contents of the top-level directory to the output directory instead of the directory itself."
    extra_args+=("--strip-components=1")
else
    echo "It does not."
fi

if [ "$par_exclude" != "" ]; then
    echo "Exclusion of files with wildcard '$par_exclude' requested."
    extra_args+=("--exclude=$par_exclude")
fi

echo "Starting extraction of tarball '$par_input' to output directory '$par_output'."
mkdir -p "$par_output"
tar --directory="$par_output" ${extra_args[@]} -xavf "$par_input"

