#!/bin/bash

set -eo pipefail

declare -A input_output_mapping=(["par_input"]="par_output" 
                                 ["par_input_multiqc"]="par_output_multiqc"
                                 ["par_input_run_information"]="par_output_run_information"
                                 ["par_input_demultiplexer_logs"]="par_output_demultiplexer_logs"
                                )

for input_argument_name in "${!input_output_mapping[@]}"
do
    input_location="${!input_argument_name}"
    output_argument_name="${input_output_mapping[$input_argument_name]}"
    output_location="${!output_argument_name}"
    echo "Publishing $input_location -> $output_location"

    echo "Creating directory if it does not exist."
    mkdir -p $(dirname "$output_location") && echo "Containing directory $output_location created"

    echo "Copying files..."
    cp -a --keep-directory-symlink "$input_location" "$output_location"

    echo "Output files for $output_location:"
    ls "$output_location"
done

echo "Grouping output from $par_input_sample_qc into $par_output_sample_qc"
mkdir -p "$par_output_sample_qc"
IFS=";" read -ra sample_qc_inputs <<< $par_input_sample_qc
for qc_dir in "${sample_qc_inputs[@]}"; do
    echo "Copying contents of $qc_dir"
    find -H -D exec "$qc_dir" -type f -maxdepth 1 -exec cp -a --keep-directory-symlink -t "$par_output_sample_qc" {} +
done