#!/bin/bash

# Create output directory
mkdir -p "$par_output"
mkdir -p "$par_output_falco"

echo
echo "par_output:         $par_output"
echo "par_output_falco:   $par_output_falco"
echo "par_output_multiqc: $par_output_multiqc"

cp -L "$par_input"/* "$par_output"
cp -rL "$par_input_falco"/* "$par_output_falco"
cp -L "$par_input_multiqc" "$par_output_multiqc"

echo
echo "Output files:"
echo "par_output:"
ls "$par_output"

echo
echo "par_output_falco:"
ls "$par_output_falco"

echo
echo "par_output_multiqc:"
ls "$par_output_multiqc"
