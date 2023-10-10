#!/bin/bash

input_file=""
output_prefix=""
mapping_file="${input_file}/mapping.txt"
cl_value=8
tax_aligner_value=0

for id_value in 0.97 0.98 0.99 1.0; do
    lotus2 -i "${input_file}" -o "${output_prefix}_${id_value}" -m "${mapping_file}" -CL "${cl_value}" -id "${id_value}" -taxAligner "${tax_aligner_value}"
done
