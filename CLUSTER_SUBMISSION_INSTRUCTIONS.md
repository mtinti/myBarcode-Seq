# Dundee cluster batch submission instructions (no shared filesystem)

These instructions submit **myBarcode-Seq** as a single batch job using `qsub`
and a wrapper script (`submit_snakemake_cluster.sh`). The script automatically
handles rsyncing the project to local scratch, running Snakemake, and rsyncing
results back to persistent storage.

> **Key difference from myRna-seq:** myBarcode-Seq does *not* handle `$TMPDIR`
> internally. The wrapper script takes care of the rsync in/out so you don't
> have to do it manually.

The wrapper automatically handles:
- Rsyncing the entire project to `$TMPDIR` (fast node-local scratch)
- Activating the conda environment
- Running Snakemake with `--use-conda` (+ optional `--use-singularity`) and `--conda-prefix` (persistent env storage)
- Rsyncing results back to persistent storage when finished

## 1) Set up the environment (one-time)

```bash
# 1. Connect to the cluster
ssh compute.dundee.ac.uk

# 2. Navigate to your lab folder
cd /cluster/majf_lab/mtinti  # Replace with your lab folder path

# 3. Clone the repository (this step is done only once)
git clone https://github.com/mtinti/myBarcode-Seq.git

# 4. Create the conda environment (this step is done only once)
conda create -n snakemake snakemake
```

## 2) Prepare the input data

```bash
# 5. Navigate to the repository
cd myBarcode-Seq

# 6. Pull the latest changes (every time)
git pull

# 7. Create the input data directory structure
mkdir -p data/genome_927
```

Copy your BAM files and reference into the data directory. For example:

```
data/TbRIT-8166/TbRIT-8166.sorted.bam
data/genome_927/TriTrypDB-68_TbruceiTREU927.gtf
```

## 3) Create and edit the config file

```bash
# 8. Make a copy of the example config
cp config/config_example.yaml config/config_rit.yaml
```

This copy serves both as the configuration for your run and as a record of how
the pipeline was executed.

Edit `config/config_rit.yaml` and apply the following changes:

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

### c) Set the Singularity image

Ensure your config contains:

```yaml
singularity_image: "/cluster/majf_lab/mtinti/rna_seq.sif"
```

This is used by each rule via `singularity:` in the `Snakefile`.

## 4) Submit the job

Update the `submit_snakemake_cluster.sh` script with the path to your local snakemake conda env

```bash
# 9. Submit the job with your custom config file
SNAKEMAKE_CONDA_PREFIX="/gpfs/uod-scale-01/cluster/majf_lab/mtinti/conda-envs" USE_SINGULARITY=1 SINGULARITY_ARGS="--bind /cluster" CONFIGFILE=config/config_rit.yaml qsub submit_snakemake_cluster.sh
```

To run without Singularity (Conda-only), set `USE_SINGULARITY=0`.

```bash
USE_SINGULARITY=0 CONFIGFILE=config/config_rit.yaml qsub submit_snakemake_cluster.sh
```

You can hard set this variables in submit_snakemake_cluster.sh instead, simply run:

```bash
qsub submit_snakemake_cluster.sh
```

Check the job queue and review the log once it finishes:

```bash
# Check job status
qstat

# Review the log (replace JOBID with your job ID)
cat snakemake_barcode_JOBID.log
```

## 5) Results

When the pipeline finishes, results are in `results/` inside your project
directory. The wrapper script rsyncs them back from scratch automatically.

Contents of `results/`:
- Sorted and indexed BAM files
- Barcode-extracted BAM files (F_plus_R, WO for ritSeq; F, R, FR, RR for oeSeq)
- BigWig coverage tracks
- featureCounts output

---

### Notes

- Because the cluster has **no shared filesystem**, the workflow runs on a
  **single node**. Do not use Snakemake's cluster submission mode.
- The wrapper script uses `--conda-prefix /cluster/majf_lab/mtinti/conda-envs`
  so that rule-level conda environments are stored on persistent lab storage.
  Snakemake creates them on the first run and reuses them on subsequent runs.
- By default the wrapper enables Singularity (`USE_SINGULARITY=1`) and
  uses `SINGULARITY_ARGS="--bind /cluster"` so the image can access lab paths.
  Set `USE_SINGULARITY=0` to run Conda-only.
- `CONFIGFILE=config/config_rit.yaml qsub ...` sets an environment variable
  that the script reads via `${CONFIGFILE:-config/config.yaml}`. The `#$ -V`
  directive in the script exports all environment variables to the job, so the
  value you set before `qsub` is available inside the running job.
- To change resource requests (cores, memory, disk), edit the SGE directives
  (`#$` lines) at the top of `submit_snakemake_cluster.sh`. Make sure `CORES`
  matches `#$ -pe smp`.

> **Tip:** Keep separate config files for each experiment. This way the pipeline
> run is fully reproducible without needing to store intermediate files.
