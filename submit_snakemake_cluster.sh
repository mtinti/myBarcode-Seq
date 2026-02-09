#!/bin/bash
#$ -adds l_hard local_free 200G
#$ -mods l_hard m_mem_free 20G
#$ -adds l_hard avx 1
#$ -cwd
#$ -V
#$ -j y
#$ -N snakemake_barcode
#$ -o snakemake_barcode_$JOB_ID.log
#$ -pe smp 40

# Exit on error and undefined variables
set -e
set -u

# ── User-configurable variables ─────────────────────────────────
CORES="${CORES:-40}"
CONFIGFILE="${CONFIGFILE:-config/config.yaml}"
CONDA_PREFIX="/cluster/majf_lab/mtinti/conda-envs"

# ── Remember where we started (persistent storage) ──────────────
PROJECT_DIR="$(pwd)"

# ── rsync entire project to fast local scratch ──────────────────
rsync -a "$PROJECT_DIR/" "$TMPDIR/myBarcode-Seq/"
cd "$TMPDIR/myBarcode-Seq"

# ── Activate conda and run ──────────────────────────────────────
eval "$(conda shell.bash hook)"
conda activate snakemake

snakemake \
  --use-conda \
  --conda-prefix "$CONDA_PREFIX" \
  --cores "$CORES" \
  --configfile "$CONFIGFILE"

# ── rsync results back to persistent storage ────────────────────
rsync -a "$TMPDIR/myBarcode-Seq/results/" "$PROJECT_DIR/results/"
