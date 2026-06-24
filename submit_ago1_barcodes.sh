#!/bin/bash
# ─────────────────────────────────────────────────────────────────────────────
# Generate one Snakemake config per sample and submit one qsub job per file.
#
# Barcode finder: ritSeq (single barcode, barcode_type=1)
#   forward_barcode: TCTGTACTATATTGAG
#   reverse_barcode: CTCAATATAGTACAGA  (reverse complement of the forward barcode)
#
# Usage:
#   ./submit_ago1_barcodes.sh            # write configs AND submit one qsub per sample
#   ./submit_ago1_barcodes.sh --dry-run  # only write the config files, do not submit
# ─────────────────────────────────────────────────────────────────────────────
set -euo pipefail

# Resolve the repo root (this script lives in it) and work from there, so the
# script can be invoked from anywhere you cloned the repo.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${SCRIPT_DIR}"

DRY_RUN=false
[[ "${1:-}" == "--dry-run" ]] && DRY_RUN=true

# ── Barcodes ────────────────────────────────────────────────────────────────
FORWARD_BARCODE="TCTGTACTATATTGAG"
REVERSE_BARCODE="CTCAATATAGTACAGA"   # reverse complement of FORWARD_BARCODE

# ── Paths ───────────────────────────────────────────────────────────────────
EXP_DIR="/cluster/majf_lab/mtinti/RNAseq/experiments/DH/Gustavo/F24A430002166_TRYtczxR"
GTF="${EXP_DIR}/genomes/tb927_v68/tb927_v68.gtf"
# BAM layout: ${EXP_DIR}/<sample>/res1/<sample>/<sample>sorted.bam

CONFIG_DIR="config/ago1"
CONDA_PREFIX_LAB="/gpfs/uod-scale-01/cluster/majf_lab/mtinti/conda-envs"

# ── Samples ─────────────────────────────────────────────────────────────────
SAMPLES=(
  WT.34.A WT.34.B WT.34.C
  WT.37.A WT.37.B WT.37.C
  WT.40.A WT.40.B WT.40.C
  ago1A.34.A ago1A.34.B ago1A.34.C
  ago1A.37.A ago1A.37.B ago1A.37.C
  ago1A.40.A ago1A.40.B ago1A.40.C
  ago1D.34.A ago1D.34.B ago1D.34.C
  ago1D.37.A ago1D.37.B ago1D.37.C
  ago1D.40.A ago1D.40.B ago1D.40.C
)

mkdir -p "${CONFIG_DIR}"

for SAMPLE in "${SAMPLES[@]}"; do
  BAM="${EXP_DIR}/${SAMPLE}/res1/${SAMPLE}/${SAMPLE}sorted.bam"
  CONFIGFILE="${CONFIG_DIR}/config_${SAMPLE}.yaml"

  cat > "${CONFIGFILE}" <<EOF
# Global defaults
threads: 8
bin_size: 1
output_dir: results
gtf: ${GTF}

samples:
  ${SAMPLE}:
    bam: ${BAM}
    method: ritSeq
    forward_barcode: ${FORWARD_BARCODE}
    reverse_barcode: ${REVERSE_BARCODE}
    merge_forward_reverse: true
EOF

  echo "Wrote ${CONFIGFILE}"

  if ! ${DRY_RUN}; then
    SNAKEMAKE_CONDA_PREFIX="${CONDA_PREFIX_LAB}" \
    CONFIGFILE="${CONFIGFILE}" \
    qsub -N "barcode_${SAMPLE}" \
         -o "snakemake_barcode_${SAMPLE}_\$JOB_ID.log" \
         submit_snakemake_cluster.sh
    echo "Submitted qsub job for ${SAMPLE}"
  fi
done

if ${DRY_RUN}; then
  echo ""
  echo "Dry run complete: ${#SAMPLES[@]} config files written under ${CONFIG_DIR}/ (no jobs submitted)."
else
  echo ""
  echo "Submitted ${#SAMPLES[@]} jobs. Monitor with: qstat"
fi
