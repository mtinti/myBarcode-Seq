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


# --- Force Miniforge (base has snakemake) ---

which conda
which python
which snakemake
type -a conda


# ── User-configurable variables ─────────────────────────────────
CORES="${CORES:-40}"
CONFIGFILE="${CONFIGFILE:-config/config.yaml}"
SNAKEMAKE_CONDA_PREFIX="${SNAKEMAKE_CONDA_PREFIX:-/gpfs/uod-scale-01/cluster/majf_lab/mtinti/conda-envs}"
SINGULARITY_ARGS="${SINGULARITY_ARGS:---bind /cluster}"

# ── Remember where we started (persistent storage) ──────────────
PROJECT_DIR="$(pwd)"

# ── rsync entire project to fast local scratch ──────────────────
rsync -a "$PROJECT_DIR/" "$TMPDIR/myBarcode-Seq/"
cd "$TMPDIR/myBarcode-Seq"

# ── Activate conda and run ──────────────────────────────────────
eval "$(conda shell.bash hook)"
conda activate snakemake

/gpfs/uod-scale-01/cluster/majf_lab/mtinti/miniforge3/bin/snakemake \
  --use-conda \
  --use-singularity \
  --singularity-args "$SINGULARITY_ARGS" \
  --conda-prefix "$SNAKEMAKE_CONDA_PREFIX" \
  --cores "$CORES" \
  --configfile "$CONFIGFILE"

# ── rsync results back to persistent storage ────────────────────
rsync -a "$TMPDIR/myBarcode-Seq/results/" "$PROJECT_DIR/results/"
