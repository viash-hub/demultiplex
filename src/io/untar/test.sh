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

INPUT_FILE="$TMPDIR/test_file.txt"
echo ">>> Creating test input file at '$TMPDIR/test_file.txt'."
echo "foo" > "$INPUT_FILE"
echo ">>> Created '$INPUT_FILE'."

echo ">>> Creating tar.gz from '$INPUT_FILE'."
TARFILE="${INPUT_FILE}.tar.gz"
tar -C "$TMPDIR" -czvf ${INPUT_FILE}.tar.gz $(basename "$INPUT_FILE")
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
tar -C "$TMPDIR" -czvf "$TMPDIR/input_test_3.tar.gz" $(basename "$TMPDIR/input_test_3")
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

echo ">>> Check for tar archive that contains a single directory starting with './'."
mkdir "$TMPDIR/input_test_4/"
cp "$INPUT_FILE" "$TMPDIR/input_test_4/"

pushd "$TMPDIR/" 
trap popd ERR
tar -czvf "$TMPDIR/input_test_4.tar.gz" ./input_test_4
popd
trap - ERR

OUTPUT_DIR_4="$TMPDIR/output_test_4/"
echo "Extracting '$TMPDIR/input_test_4.tar.gz' to '$OUTPUT_DIR_4'".
./$meta_functionality_name \
   --input "$TMPDIR/input_test_4.tar.gz" \
   --output "$OUTPUT_DIR_4"

echo ">>> Check whether extracted file exists"
[[ ! -f "$OUTPUT_DIR_4/test_file.txt" ]] && echo "Output file could not be found!" && exit 1

echo ">>> Creating test tarball containing only 1 top-level directory, but it is nested."
mkdir -p "$TMPDIR/input_test_5/nested/"
cp "$INPUT_FILE" "$TMPDIR/input_test_5/nested/"
tar -C "$TMPDIR" -czvf "$TMPDIR/input_test_5.tar.gz" $(basename "$TMPDIR/input_test_5")
TARFILE_5="$TMPDIR/input_test_5.tar.gz"

echo ">>> Creating temporary output directory for test 5."
OUTPUT_DIR_5="$TMPDIR/output_test_5/"
mkdir "$OUTPUT_DIR_5"

echo "Extracting '$TARFILE_5' to '$OUTPUT_DIR_5'".
./$meta_functionality_name \
   --input "$TARFILE_5" \
   --output "$OUTPUT_DIR_5"

echo ">>> Check whether extracted file exists"
[[ ! -f "$OUTPUT_DIR_5/nested/test_file.txt" ]] && echo "Output file could not be found!" && exit 1

echo ">>> Creating test tarball containing two top-level directories."
mkdir -p "$TMPDIR/input_test_6/number_1/"
mkdir "$TMPDIR/input_test_6/number_2/"
cp "$INPUT_FILE" "$TMPDIR/input_test_6/number_1/"
tar -C "$TMPDIR" -czvf "$TMPDIR/input_test_6.tar.gz" $(basename "$TMPDIR/input_test_6")
TARFILE_6="$TMPDIR/input_test_6.tar.gz"

echo ">>> Creating temporary output directory for test 6."
OUTPUT_DIR_6="$TMPDIR/output_test_6/"
mkdir "$OUTPUT_DIR_6"

echo "Extracting '$TARFILE_6' to '$OUTPUT_DIR_6'".
./$meta_functionality_name \
   --input "$TARFILE_6" \
   --output "$OUTPUT_DIR_6"

echo ">>> Check whether extracted file exists"
[[ ! -f "$OUTPUT_DIR_6/number_1/test_file.txt" ]] && echo "Output file could not be found!" && exit 1
[[ ! -d "$OUTPUT_DIR_6/number_2" ]] && echo "Output directory could not be found!" && exit 1

echo ">>> Test finished successfully"
