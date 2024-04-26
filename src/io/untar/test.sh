#!/usr/bin/env bash

set -eo pipefail

# create tempdir
echo ">>> Creating temporary test directory."
TMPDIR=$(mktemp -d "$meta_temp_dir/$meta_functionality_name-XXXXXX")
function clean_up {
  [[ -d "$TMPDIR" ]] && rm -r "$TMPDIR"
}
echo ">>> Created temporary directory '$TMPDIR'."

INPUT_FILE="$TMPDIR/test_file.txt"
echo ">>> Creating test input file at '$TMPDIR/test_file.txt'."
echo "foo" > "$INPUT_FILE"
echo ">>> Created '$INPUT_FILE'."

echo ">>> Creating tar.gz from '$INPUT_FILE'."
TARFILE="${INPUT_FILE}.tar.gz"
tar czvf ${INPUT_FILE}.tar.gz $(basename "$INPUT_FILE") -C "$TMPDIR"
[[ ! -f "$TARFILE" ]] && echo ">>> Test setup failed: could not create tarfile." && exit 1
echo ">>> '$TARFILE' created."

echo ">>> Check whether tar.gz can be extracted"
echo ">>> Creating temporary output directory for test 1."
OUTPUT_DIR_1="$TMPDIR/output_test_1/"
mkdir "$OUTPUT_DIR_1"

echo ">>> Extracting '$TARFILE' to '$OUTPUT_DIR_1'".
./$meta_functionality_name \
   --input "$TARFILE" \
   --output "$OUTPUT_DIR_1"

echo ">>> Check whether extracted file exists"
[[ ! -f "$OUTPUT_DIR_1/test_file.txt" ]] && echo "Output file could not be found. Output directory contents: " && ls "$OUTPUT_DIR_1" && exit 1

echo ">>> Creating temporary output directory for test 2."
OUTPUT_DIR_2="$TMPDIR/output_test_2/"
mkdir "$OUTPUT_DIR_2"

echo ">>> Extracting '$TARFILE' to '$OUTPUT_DIR_2', excluding '$test_file.txt'".
./$meta_functionality_name \
   --input "$TARFILE" \
   --output "$OUTPUT_DIR_2" \
   --exclude 'test_file.txt'

echo ">>> Check whether excluded file was not extracted"
[[ -f "$OUTPUT_DIR_2/test_file.txt" ]] && echo "File should have been excluded! Output directory contents:" && ls "$OUTPUT_DIR_2" && exit 1

echo ">>> Creating test tarball containing only 1 top-level directory."
mkdir "$TMPDIR/input_test_3/"
cp "$INPUT_FILE" "$TMPDIR/input_test_3/"
tar czvf "$TMPDIR/input_test_3.tar.gz" $(basename "$TMPDIR/input_test_3") -C "$TMPDIR"
TARFILE_3="$TMPDIR/input_test_3.tar.gz"

echo ">>> Creating temporary output directory for test 3."
OUTPUT_DIR_3="$TMPDIR/output_test_3/"
mkdir "$OUTPUT_DIR_3"

echo "Extracting '$TARFILE_3' to '$OUTPUT_DIR_3'".
./$meta_functionality_name \
   --input "$TARFILE_3" \
   --output "$OUTPUT_DIR_3"

echo ">>> Check whether extracted file exists"
[[ ! -f "$OUTPUT_DIR_3/test_file.txt" ]] && echo "Output file could not be found!" && exit 1

echo ">>> Test finished successfully"
