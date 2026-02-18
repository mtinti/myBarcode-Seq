# myBarcode-seq Snakemake pipeline

[![DOI](https://zenodo.org/badge/DOI/10.5281/zenodo.18682390.svg)](https://doi.org/10.5281/zenodo.18682390)

This workflow implements two barcode-processing modes:

- **ritSeq**: single barcode, optionally merges F/R (`barcode_type=1`).
- **oeSeq**: dual barcodes for over-expression / cosmid libraries (`barcode_type=2`).

## Contents
- `Snakefile` — workflow entrypoint.
- `config/config.yaml` — sample definitions and parameters.
- `workflow/scripts/extract_barcodes.py` — renamed barcode extractor.
- `workflow/envs/mybarcode.yaml` — conda environment with samtools, pysam, deeptools, subread, biopython, tqdm.

## Configure
Edit `config/config.yaml`:
- Set `gtf` to your annotation.
- Add samples under `samples:` with `bam`, `method` (`ritSeq` or `oeSeq`), `forward_barcode`, `reverse_barcode`, and (for ritSeq) `merge_forward_reverse`.
- Adjust `threads`, `bin_size`, and `output_dir` as needed.

Outputs are written to `results/<sample>/<sample>.*`.

## Run
```bash
snakemake --use-conda --cores 8
```
Adjust `--cores` to match your machine. The workflow will:
- Sort and index inputs.
- Filter proper pairs for ritSeq (to match the legacy commands).
- Call `extract_barcodes.py` in the correct mode.
- Build BAM/BAI and BigWig files via `bamCoverage`.
- Run featureCounts with the same arguments you provided.

## Test configurations
Two lightweight test configurations are available under `test_data/`:

```bash
snakemake --use-conda --cores 8 --configfile test_data/test_oe/config_test.yaml
snakemake --use-conda --cores 8 --configfile test_data/test_rit/config_test.yaml
```

These run the workflow against the `oeSeq` and `ritSeq` test datasets, respectively.

## Notes
- The workflow assumes input BAMs exist at the paths listed in the config.
- BigWigs use `bin_size` from the config (default 1).
- FeatureCounts outputs both `*.counts.txt` and the accompanying `*.counts.txt.summary`.


Historical barcodes used:
```python
barcode_dictionary ={
	'ritSeqTb':{'f':'GCCTCGCGA', 'r':'TCGCGAGGC'},
    'CosLib':{'f':'GCGGCCGCTCTAGAACTAGT', 'r':'AGACATGATGCTTTTAAGAG'},
    'OElib':{'f':'GATAGAGTGGTACCGGCCGG', 'r':'CAATGATAGAGTGGCCGGCC'},
    'OEtbrucei':{'f':'GATAGAGTGGTACCGGCCGG', 'r':'CAATGATAGAGTGGCCGGCC'},
    'anna_utr':{'f':'CTGACTCCTTAAGGGCC','r':'TAACTGAGGCCGGC'},
    'cat_cell_cycle':{'f':'CTCTTAAAAGCATCATGTCT', 'r':'ACTAGTTCTAGAGCGGCCGC'},
    'glover_2015':{'f':'GCCTCGCGA','r':'TCGCGAGGC'},
    'PkCos' :{'f':'TAGGGATAACAGGGTAATT','r':'ATTCTCATGTTTGACCGCT'}
    }
```
