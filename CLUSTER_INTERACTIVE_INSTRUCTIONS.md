# Dundee cluster interactive instructions (no shared filesystem)

These notes describe how to run the **myBarcode-Seq** Snakemake workflow on the
Dundee cluster **inside a single interactive job**. Because the cluster has **no
shared filesystem**, the entire project (including BAM inputs) must be copied to
node-local scratch (`$TMPDIR`) before running, and results must be synced back
afterwards.

> **Key difference from myRna-seq:** myBarcode-Seq does *not* handle `$TMPDIR`
> internally. You must manually rsync the project to scratch before running and
> rsync results back when finished.

## 1) Start an interactive session

```bash
# 1. Connect to the cluster
ssh compute.dundee.ac.uk

# 2. Start a screen session (protects against connection loss)
screen -S snakemake_job

# If connection drops, reconnect with:
# ssh compute.dundee.ac.uk
# screen -r snakemake_job

# 3. Request an interactive session with the SGE settings used by this pipeline
qrsh -pe smp 40 \
  -adds l_hard local_free 200G \
  -mods l_hard m_mem_free 20G \
  -adds l_hard avx 1
```

Once the session starts you will be on a compute node.

## 2) One-time setup

```bash
# 4. Navigate to your lab folder
cd /cluster/majf_lab/mtinti  # Replace with your lab folder path

# 5. Clone the repository (this step is done only once)
git clone https://github.com/mtinti/myBarcode-Seq.git

# 6. Create the conda environment (this step is done only once)
conda create -n snakemake snakemake
```

## 3) Prepare the input data

myBarcode-Seq takes BAM files as input (typically the output of myRna-seq with
`copy_bam: True`). Place them under the `data/` directory.

```bash
# 7. Navigate to the repository
cd /cluster/majf_lab/mtinti/myBarcode-Seq

# 8. Pull the latest changes (every time)
git pull

# 9. Create the input data directory structure
mkdir -p data/genome_927
```

Copy your BAM files and reference into the data directory. For example:

```
data/TbRIT-8166/TbRIT-8166.sorted.bam
data/genome_927/TriTrypDB-68_TbruceiTREU927.gtf
```

## 4) Create and edit the config file

Start from `config/config_example.yaml`, which documents every available option.
Example configs for common experiments are also provided:
- `config/config_rit.yaml` — ritSeq (single barcode)
- `config/config_tboe.yaml` — oeSeq (dual barcode, *T. brucei* overexpression)

To create a new config from scratch:

```bash
# 10. Make a copy of the example config
cp config/config_example.yaml config/config_myrun.yaml
```

Or start from one of the provided examples if it matches your experiment:

```bash
cp config/config_rit.yaml config/config_myrun.yaml
```

This copy serves both as the configuration for your run and as a record of how
the pipeline was executed.

Edit your config file and apply the following changes:

### a) Set the GTF annotation

Replace:

```yaml
gtf: /path/to/genome.gtf
```

with the path to your annotation file relative to the project root:

```yaml
gtf: data/genome_927/TriTrypDB-68_TbruceiTREU927.gtf
```

### b) Configure your samples

Update the `samples:` block with your BAM paths, barcode sequences, and method.
See `config/config_example.yaml` for the full format.

## 5) rsync project to local scratch

```bash
# 11. Copy the entire project to the compute node's fast local drive
rsync -a /cluster/majf_lab/mtinti/myBarcode-Seq/ $TMPDIR/myBarcode-Seq/
```

## 6) Run the pipeline

```bash
# 12. Move to the scratch copy
cd $TMPDIR/myBarcode-Seq

# 13. Activate conda
conda activate snakemake

# 14. Run Snakemake
snakemake \
  --use-conda \
  --conda-prefix /cluster/majf_lab/mtinti/conda-envs \
  --cores 40 \
  --configfile config/config_rit.yaml
```

The `--conda-prefix` flag stores conda environments on persistent lab storage.
Snakemake creates them on the first run and reuses them on subsequent runs,
avoiding a rebuild every time you work from `$TMPDIR`.

## 7) rsync results back to persistent storage

```bash
# 15. Copy results back to your lab folder
rsync -a $TMPDIR/myBarcode-Seq/results/ /cluster/majf_lab/mtinti/myBarcode-Seq/results/
```

---

### Notes

- Because the cluster has **no shared filesystem**, the workflow runs on a
  **single node**. Do not use Snakemake's cluster submission mode.
- The pipeline uses a single conda environment (`workflow/envs/mybarcode.yaml`)
  containing samtools, pysam, deeptools, subread, biopython, and tqdm.
- `--conda-prefix /cluster/majf_lab/mtinti/conda-envs` is critical: without it,
  Snakemake would store envs inside `$TMPDIR/.snakemake/conda/` and rebuild them
  every job.

> **Tip:** Keep separate config files for each experiment. This way the pipeline
> run is fully reproducible without needing to store intermediate files.
