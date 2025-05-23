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
    cp -rL "$input_location" "$output_location"

    echo "Output files for $output_location:"
    ls "$output_location"
done

echo "Grouping output from $par_input_falco into $par_output_falco"
mkdir -p "$par_output_falco"
IFS=";" read -ra falco_inputs <<< $par_input_falco
for falco_dir in "${falco_inputs[@]}"; do
    echo "Copying contents of $falco_dir"
    find -H -D exec "$falco_dir" -type f -maxdepth 1 -exec cp -t "$par_output_falco" {} +
done