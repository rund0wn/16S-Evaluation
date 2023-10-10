#!/bin/bash

indir=""
outdir=""
Ftrunc=""
Rtrunc=""

#Run without truncating
nextflow run nf-core/ampliseq \
    -r 2.3.2 \
    -profile singularity \
    --input "$indir" \
    --dada_ref_taxonomy rdp=18 \
    --skip_cutadapt \
    --metadata "$indir/Metadata.tsv"
    --outdir "$outdir"

#Run with truncating
nextflow run nf-core/ampliseq \
    -r 2.3.2 \
    -profile singularity \
    --input "$indir" \
    --dada_ref_taxonomy rdp=18 \
    --skip_cutadapt \
    --trunclenf $Ftrunc \
    --trunclenr $Rtrunc \
    --metadata "$indir/Metadata.tsv"
    --outdir "$outdir"

    
