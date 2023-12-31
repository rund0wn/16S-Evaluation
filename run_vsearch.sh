#!/bin/sh

# This is an example of a pipeline using vsearch to process data in the
# Mothur 16S rRNA MiSeq SOP tutorial dataset to perform initial paired-end
# read merging, quality filtering, chimera removal and OTU clustering.

INDIR=""
THREADS=1
PERL=$(which perl)
VSEARCH=$(which vsearch)
SWARM=$(which swarm)
REF=gold.fasta
GOLD="https://mothur.s3.us-east-2.amazonaws.com/wiki/silva.gold.bacteria.zip"
RDP="https://www.drive5.com/sintax/rdp_16s_v18.fa.gz"

CLUSTERID=0.98
MAXEE=1.0

date
cd $INDIR
wget $RDP

echo
echo Obtaining Gold reference database for chimera detection

if [ ! -e gold.fasta ]; then

    if [ ! -e silva.gold.bacteria.zip ]; then
        wget $GOLD
    fi

    echo Decompressing and reformatting...
    unzip -p silva.gold.bacteria.zip silva.gold.align | \
        sed -e "s/[.-]//g" > gold.fasta

fi

# Enter subdirectory

echo
echo Checking FASTQ format version for one file

$VSEARCH --fastq_chars $(ls -1 *.fastq | head -1)

# Process samples

for f in *_1.fastq; do

    s=$(basename "$f" | cut -d_ -f1)
    r="${s}_2.fastq"

    echo
    echo ====================================
    echo Processing sample $s
    echo ====================================
    echo

    $VSEARCH --fastq_mergepairs $f --threads $THREADS --reverse $r --fastqout $s.merged.fastq --fastq_eeou
t


    # Commands to demultiplex and remove tags and primers
    # using e.g. cutadapt may be added here.

    echo
    echo Calculate quality statistics
    echo

    $VSEARCH --fastq_eestats $s.merged.fastq \
        --output $s.stats

    echo
    echo Quality filtering
    echo

    $VSEARCH --fastq_filter $s.merged.fastq \
        --fastq_maxee $MAXEE \
        --fastq_minlen 10 \
        --fastq_maxlen 500 \
        --fastq_maxns 0 \
        --fastaout $s.filtered.fasta \
        --fasta_width 0

    echo
    echo Dereplicate at sample level and relabel with sample.n
    echo

    $VSEARCH --derep_fulllength $s.filtered.fasta \
        --strand plus \
        --output $s.derep.fasta \
        --sizeout \
        --relabel $s. \
        --fasta_width 0

done
# At this point there should be one fasta file for each sample
# It should be quality filtered and dereplicated.

echo
echo ====================================
echo Processing all samples together
echo ====================================
echo
echo Merge all samples

cat *.derep.fasta > all.fasta

echo
echo Sum of unique sequences in each sample: $(cat all.fasta | grep -c "^>")
echo
echo Dereplicate across samples
echo

$VSEARCH --derep_fulllength all.fasta \
    --threads $THREADS \
    --sizein \
    --sizeout \
    --fasta_width 0 \
    --uc all.derep.uc \
    --output derep.fasta

echo
echo Unique sequences: $(grep -c "^>" derep.fasta)
echo
echo Cluster sequences using VSEARCH
echo

$VSEARCH --cluster_size derep.fasta \
    --threads $THREADS \
    --id $CLUSTERID \
    --strand plus \
    --sizein \
    --sizeout \
    --fasta_width 0 \
    --centroids centroids.fasta

echo
echo Cluster with Swarm using d=1 and fastidious mode
echo

$SWARM derep.fasta \
   --threads $THREADS \
   --differences 1 \
   --fastidious \
   --seeds centroids.fasta \
   --usearch-abundance \
   --output /dev/null

echo
echo Clusters: $(grep -c "^>" centroids.fasta)
echo
echo Sort and remove singletons
echo

$VSEARCH --sortbysize centroids.fasta \
    --threads $THREADS \
    --sizein \
    --sizeout \
    --fasta_width 0 \
    --minsize 2 \
    --output sorted.fasta

echo
echo Non-singleton clusters: $(grep -c "^>" sorted.fasta)
echo 
echo De novo chimera detection
echo

$VSEARCH --uchime_denovo sorted.fasta \
    --sizein \
    --sizeout \
    --fasta_width 0 \
    --qmask none \
    --nonchimeras denovo.nonchimeras.fasta \

echo
echo Unique sequences after de novo chimera detection: $(grep -c "^>" denovo.nonchimeras.fasta)
echo
echo Reference chimera detection
echo

$VSEARCH --uchime_ref denovo.nonchimeras.fasta \
    --threads $THREADS \
    --db $REF \
    --sizein \
    --sizeout \
    --fasta_width 0 \
    --qmask none \
    --dbmask none \
    --nonchimeras nonchimeras.fasta

echo
echo Unique sequences after reference-based chimera detection: $(grep -c "^>" nonchimeras.fasta)
echo
echo Relabel OTUs
echo

$VSEARCH --fastx_filter nonchimeras.fasta \
    --threads $THREADS \
    --sizein \
    --sizeout \
    --fasta_width 0 \
    --relabel OTU_ \
    --fastaout otus.fasta

echo
echo Number of OTUs: $(grep -c "^>" otus.fasta)
echo
echo Map sequences to OTUs by searching
echo

$VSEARCH --usearch_global all.fasta \
    --threads $THREADS \
    --db otus.fasta \
    --id $CLUSTERID \
    --strand plus \
    --sizein \
    --sizeout \
    --fasta_width 0 \
    --qmask none \
    --dbmask none \
    --otutabout otutab.txt

echo
echo Sort OTU table numerically
echo

sort -k1.5n otutab.txt > otutab.sorted.txt

echo
echo Done

date
