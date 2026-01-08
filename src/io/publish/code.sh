#!/bin/bash

set -eo pipefail

# Always consolidate sample QC outputs into a single directory
echo "Grouping output from $par_input_sample_qc into $par_output_sample_qc"
mkdir -p "$par_output_sample_qc"
IFS=";" read -ra sample_qc_inputs <<< $par_input_sample_qc
for qc_dir in "${sample_qc_inputs[@]}"; do
    echo "Processing contents of $qc_dir"
    find -H "$qc_dir" -type f -maxdepth 1 -exec ln -s {} "$par_output_sample_qc/" \;
done

# Check if we should skip publishing to publish_dir
if [ "$par_skip" == "true" ]; then
    echo "Skipping publishing to publish_dir (--skip is true)."
    echo "Creating symlinks for other outputs in work directory..."
    
    # Create symlinks for other outputs (so they exist as expected outputs)
    ln -sf "$par_input" "$par_output"
    ln -sf "$par_input_multiqc" "$par_output_multiqc"
    ln -sf "$par_input_run_information" "$par_output_run_information"
    ln -sf "$par_input_demultiplexer_logs" "$par_output_demultiplexer_logs"
    ln -sf "$par_input_demultiplex_params" "$par_output_demultiplex_params"
    
    exit 0
fi

# Normal publishing mode - copy everything to the specified output locations
declare -A input_output_mapping=(["par_input"]="par_output" 
                                 ["par_input_multiqc"]="par_output_multiqc"
                                 ["par_input_run_information"]="par_output_run_information"
                                 ["par_input_demultiplexer_logs"]="par_output_demultiplexer_logs"
                                 ["par_input_demultiplex_params"]="par_output_demultiplex_params"
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

# Sample QC was already consolidated at the top into $par_output_sample_qc
# No additional copying needed - it's already in the right place
echo "QC consolidation complete at $par_output_sample_qc"
