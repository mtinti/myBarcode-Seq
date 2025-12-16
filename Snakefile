"""Snakemake workflow for myBarcode-seq.

This pipeline supports two modes:
- ritSeq: single barcode with optional F/R merge (barcode_type=1)
- oeSeq: dual barcode overexpression library (barcode_type=2)
"""

import os
from pathlib import Path

configfile: "config/config.yaml"

SAMPLES = config.get("samples", {})
if not SAMPLES:
    raise ValueError("No samples defined in config/config.yaml under `samples`.")

OUTPUT_DIR = config.get("output_dir", "results")
BASE = f"{OUTPUT_DIR}" + "/{sample}/{sample}"
THREADS = config.get("threads", 8)
BIN_SIZE = config.get("bin_size", 1)
GTF = config["gtf"]

rit_samples = [s for s, meta in SAMPLES.items() if meta["method"] == "ritSeq"]
oe_samples = [s for s, meta in SAMPLES.items() if meta["method"] == "oeSeq"]


def prefix(sample: str) -> str:
    """Return the base path (without extension) for a sample outputs."""
    return f"{OUTPUT_DIR}/{sample}/{sample}"


def rit_targets(sample: str):
    base = prefix(sample)
    return [
        f"{base}.sorted.bam",
        f"{base}.sorted.bam.bai",
        f"{base}.sorted_dedup.bam",
        f"{base}.sorted_dedup.bam.bai",
        f"{base}.sorted_dedup.bam.bw",
        f"{base}.sorted_dedup_F_plus_R.bam",
        f"{base}.sorted_dedup_F_plus_R.bam.bai",
        f"{base}.sorted_dedup_F_plus_R.bam.bw",
        f"{base}.sorted_dedup_WO.bam",
        f"{base}.sorted_dedup_WO.bam.bai",
        f"{base}.sorted_dedup_WO.bam.bw",
        f"{base}.counts.txt",
        f"{base}.counts.txt.summary",
    ]


def oe_targets(sample: str):
    base = prefix(sample)
    return [
        f"{base}.sorted.bam",
        f"{base}.sorted.bam.bai",
        f"{base}.sorted_F.bam",
        f"{base}.sorted_F.bam.bai",
        f"{base}.sorted_R.bam",
        f"{base}.sorted_R.bam.bai",
        f"{base}.sorted_FR.bam",
        f"{base}.sorted_FR.bam.bai",
        f"{base}.sorted_RR.bam",
        f"{base}.sorted_RR.bam.bai",
        f"{base}.sorted_F.bam.bw",
        f"{base}.sorted_R.bam.bw",
        f"{base}.sorted_FR.bam.bw",
        f"{base}.sorted_RR.bam.bw",
        f"{base}.counts.txt",
        f"{base}.counts.txt.summary",
    ]


rule all:
    input:
        [t for s in rit_samples for t in rit_targets(s)] +
        [t for s in oe_samples for t in oe_targets(s)]


def input_bam(wc):
    return SAMPLES[wc.sample]["bam"]


rule sort_input:
    """Sort the input BAM."""
    input:
        bam=input_bam
    output:
        bam=f"{OUTPUT_DIR}" + "/{sample}/{sample}.sorted.bam"
    log:
        "logs/{sample}/sort_input.log"
    threads: THREADS
    conda:
        "workflow/envs/mybarcode.yaml"
    shell:
        "samtools sort -@ {threads} -o {output.bam} {input.bam} > {log} 2>&1"


rule index_bam:
    """Index any BAM requested downstream."""
    input:
        bam="{path}.bam"
    output:
        bai="{path}.bam.bai"
    log:
        "logs/{path}.index.log"
    threads: 1
    conda:
        "workflow/envs/mybarcode.yaml"
    shell:
        "samtools index {input.bam} {output.bai} > {log} 2>&1"


rule sort_dedup_rit:
    """Second sort to produce the deduped-sorted input expected by the legacy commands."""
    input:
        bam=f"{OUTPUT_DIR}" + "/{sample}/{sample}.sorted.bam"
    output:
        bam=temp(f"{OUTPUT_DIR}" + "/{sample}/{sample}.sorted_dedup.pre.bam")
    log:
        "logs/{sample}/sort_dedup_rit.log"
    threads: THREADS
    conda:
        "workflow/envs/mybarcode.yaml"
    shell:
        "samtools sort -@ {threads} -o {output.bam} {input.bam} > {log} 2>&1"


rule filter_proper_pairs_rit:
    """Retain properly paired reads (-f 2)."""
    input:
        bam=f"{OUTPUT_DIR}" + "/{sample}/{sample}.sorted_dedup.pre.bam"
    output:
        bam=f"{OUTPUT_DIR}" + "/{sample}/{sample}.sorted_dedup.bam"
    log:
        "logs/{sample}/filter_proper_pairs_rit.log"
    threads: THREADS
    conda:
        "workflow/envs/mybarcode.yaml"
    shell:
        "samtools view -b -f 2 -@ {threads} -o {output.bam} {input.bam} > {log} 2>&1"


rule extract_barcodes_rit:
    """Single-barcode mode (ritSeq)."""
    input:
        bam=f"{OUTPUT_DIR}" + "/{sample}/{sample}.sorted_dedup.bam",
        bai=f"{OUTPUT_DIR}" + "/{sample}/{sample}.sorted_dedup.bam.bai"
    output:
        f_plus_r=f"{OUTPUT_DIR}" + "/{sample}/{sample}.sorted_dedup_F_plus_R.bam",
        wo=f"{OUTPUT_DIR}" + "/{sample}/{sample}.sorted_dedup_WO.bam"
    log:
        "logs/{sample}/extract_barcodes_rit.log"
    params:
        f=lambda wc: SAMPLES[wc.sample]["forward_barcode"],
        r=lambda wc: SAMPLES[wc.sample]["reverse_barcode"],
        merge=lambda wc: str(SAMPLES[wc.sample].get("merge_forward_reverse", True))
    threads: THREADS
    conda:
        "workflow/envs/mybarcode.yaml"
    shell:
        "python workflow/scripts/extract_barcodes.py {input.bam} {params.f} {params.r} 1 {params.merge} > {log} 2>&1"


rule extract_barcodes_oe:
    """Dual-barcode mode (oeSeq)."""
    input:
        bam=f"{OUTPUT_DIR}" + "/{sample}/{sample}.sorted.bam",
        bai=f"{OUTPUT_DIR}" + "/{sample}/{sample}.sorted.bam.bai"
    output:
        f=f"{OUTPUT_DIR}" + "/{sample}/{sample}.sorted_F.bam",
        r=f"{OUTPUT_DIR}" + "/{sample}/{sample}.sorted_R.bam",
        fr=f"{OUTPUT_DIR}" + "/{sample}/{sample}.sorted_FR.bam",
        rr=f"{OUTPUT_DIR}" + "/{sample}/{sample}.sorted_RR.bam",
        wo=f"{OUTPUT_DIR}" + "/{sample}/{sample}.sorted_WO.bam"
    log:
        "logs/{sample}/extract_barcodes_oe.log"
    params:
        f=lambda wc: SAMPLES[wc.sample]["forward_barcode"],
        r=lambda wc: SAMPLES[wc.sample]["reverse_barcode"]
    threads: THREADS
    conda:
        "workflow/envs/mybarcode.yaml"
    shell:
        "python workflow/scripts/extract_barcodes.py {input.bam} {params.f} {params.r} 2 > {log} 2>&1"


rule bam_coverage:
    """Generate bigWig coverage from BAM."""
    input:
        bam="{path}.bam",
        bai="{path}.bam.bai"
    output:
        bw="{path}.bam.bw"
    log:
        "logs/{path}.bamCoverage.log"
    threads: THREADS
    conda:
        "workflow/envs/mybarcode.yaml"
    shell:
        "bamCoverage -bs {BIN_SIZE} -b {input.bam} -o {output.bw} -p {threads} > {log} 2>&1"

        
def featurecounts_inputs(wc):
    """Choose featureCounts BAMs based on sample method."""
    base = f"{OUTPUT_DIR}/{wc.sample}/{wc.sample}"
    method = SAMPLES[wc.sample]["method"]
    if method == "ritSeq":
        return [
            f"{base}.sorted_dedup.bam",
            f"{base}.sorted_dedup_F_plus_R.bam",
            f"{base}.sorted_dedup_WO.bam",
            f"{base}.sorted.bam",
        ]
    elif method == "oeSeq":
        return [
            f"{base}.sorted.bam",
            f"{base}.sorted_F.bam",
            f"{base}.sorted_R.bam",
            f"{base}.sorted_FR.bam",
            f"{base}.sorted_RR.bam",
        ]
    else:
        raise ValueError(f"Unknown method for sample {wc.sample}")


rule featurecounts:
    input:
        featurecounts_inputs
    output:
        counts=f"{OUTPUT_DIR}" + "/{sample}/{sample}.counts.txt",
        summary=f"{OUTPUT_DIR}" + "/{sample}/{sample}.counts.txt.summary"
    log:
        "logs/{sample}/featurecounts.log"
    threads: THREADS
    conda:
        "workflow/envs/mybarcode.yaml"
    shell:
        (
            "featureCounts -p -B -C -M -T {threads} "
            "-t transcript -g gene_id -a {GTF} "
            "-o {output.counts} "
            "{input} > {log} 2>&1"
        )
