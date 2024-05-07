#!/usr/bin/env bash

set -eo pipefail

extra_args=()

TMPDIR=$(mktemp -d "$meta_temp_dir/$meta_functionality_name-XXXXXX")
function clean_up {
  [[ -d "$TMPDIR" ]] && rm -r "$TMPDIR"
}
trap clean_up EXIT

# Check if tarball contains 1 top-level directory. If so, extract the contents of the
# directory to the output directory instead of the directory itself.
echo "Directory contents:"
tar -taf "${par_input}" > "$TMPDIR/tar_contents.txt"
cat "$TMPDIR/tar_contents.txt"

printf "Checking if tarball contains only a single top-level directory: "
if [[ $(grep -o -E '^[./]*[^/]+/$' "$TMPDIR/tar_contents.txt" | uniq | wc -l) -eq 1 ]]; then
    echo "It does."
    echo "Extracting the contents of the top-level directory to the output directory instead of the directory itself."
    # The directory can be both of the format './<directory>' (or ././<directory>) or just <directory>
    # Adjust the number of stripped components accordingly by looking for './' at the beginning of the file.
    starting_relative=$(grep -oP -m 1 '^(./)*' "$TMPDIR/tar_contents.txt" | tr -d '\n' | wc -c)
    n_strips=$(( ($starting_relative / 2)+1 ))
    extra_args+=("--strip-components=$n_strips")
else
    echo "It does not."
fi

if [ "$par_exclude" != "" ]; then
    echo "Exclusion of files with wildcard '$par_exclude' requested."
    extra_args+=("--exclude=$par_exclude")
fi

echo "Starting extraction of tarball '$par_input' to output directory '$par_output'."
mkdir -p "$par_output"
echo "executing 'tar --no-same-owner --no-same-permissions --directory=$par_output ${extra_args[@]} -xavf $par_input'"
tar --no-same-owner --no-same-permissions --directory="$par_output" ${extra_args[@]} -xavf "$par_input"

