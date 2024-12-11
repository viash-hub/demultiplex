#!/bin/bash

echo "Publishing $par_input -> $par_output"
echo "Publishing $par_input_falco -> $par_output_falco"
echo "Publishing $par_input_multiqc -> $par_output_multiqc"

echo
echo "Creating directory if it does not exist:"
mkdir -p $(dirname "$par_output") && echo "Containing directory $par_output created"
mkdir -p $(dirname "$par_output_falco") && echo "Containing directory $par_output_falco created"
mkdir -p $(dirname "$par_output_multiqc") && echo "Containing directory $par_output_multiqc created"

echo
echo "Copying files..."
cp -rL "$par_input" "$par_output"
cp -rL "$par_input_falco" "$par_output_falco"
cp -rL "$par_input_multiqc" "$par_output_multiqc"

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
