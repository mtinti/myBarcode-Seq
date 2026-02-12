# Plan: add Singularity support alongside Conda

## Goal
Enable reproducible execution with **both**:
- `--use-conda` for rule environments
- `--use-singularity` for runtime isolation via a shared image

Default image path in config:

```yaml
singularity_image: "/cluster/majf_lab/mtinti/rna_seq.sif"
```

## Phase 1 — Configuration and defaults
1. Add `singularity_image` to config templates.
2. Keep it user-overridable per run via `--config singularity_image=/path/to/other.sif`.
3. Document that this value points to a lab-maintained `.sif` image.

## Phase 2 — Snakefile integration
1. Read the image path once near existing globals:
   - `SINGULARITY_IMAGE = config.get("singularity_image")`
2. Add a shared helper so each rule can opt into the same container image.
3. Add `singularity: SINGULARITY_IMAGE` to rules that currently use
   `workflow/envs/mybarcode.yaml`.
4. Keep existing `conda:` directives so Conda remains available.

> Note: Snakemake only uses Singularity for rules that define a container.

## Phase 3 — Cluster wrappers and run commands
1. Update docs and wrappers to include both execution flags:

```bash
snakemake \
  --use-conda \
  --use-singularity \
  --singularity-args "--bind /cluster" \
  --cores 40 \
  --configfile config/config_rit.yaml
```

2. Keep `--conda-prefix /cluster/majf_lab/mtinti/conda-envs` for persistent envs.
3. Ensure bind mounts include any locations used by BAM/GTF inputs.

## Phase 4 — Validation
1. Dry-run check:
   - `snakemake -n --use-conda --use-singularity --configfile <config>`
2. Run one ritSeq and one oeSeq sample.
3. Confirm outputs and logs are unchanged except runtime wrapper details.

## Risks and mitigations
- **Image missing tools**: validate `samtools`, `python`, `bamCoverage`, `featureCounts`.
- **Bind path issues**: standardize `--singularity-args "--bind /cluster"`.
- **Conda + container overlap confusion**: keep docs explicit that Conda handles
  software envs while Singularity provides host/runtime consistency.

## Acceptance criteria
- Configs contain `singularity_image` default.
- Snakefile supports per-rule container with a single config-driven image.
- Cluster instructions include `--use-singularity` usage.
- Test run completes for both `ritSeq` and `oeSeq` modes.
