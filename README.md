# Using EPA-NG for IBA

## Setup

1. Reference tree data was obtained by cloning https://github.com/ronquistlab/big-trees
   and symlinking `data/train_data/` contents into `data/`.
2. On Rackham, create a directory for data under 
   `/proj/snic2020-16-248/nobackup/IBA-epa-ng/data` and place `ASV_sequences.fna`
   (ASV sequences from swedish samples) there as well as `asv_taxa.lep.tsv` 
   (taxonomic assignments for Lepidoptera ASVs using SINTAX)
3. Extracted sequences for Lepidoptera using `seqtk` and stored as `data/lep.
   fasta`
4. Create the conda environment from `environment.yml` and activate it
5. Download `raxml-ng` from https://github.com/amkozlov/raxml-ng#installation-instructions, 
   unzip the file and move the `epa-ng` binary to `$CONDA_PREFIX/bin`.

## Configuration

The default config is:
```yaml
input:
  reference_tree: "data/backbone.nex"
  reference_msa: "data/lep_backbone_aln.nex"
  query: "data/lep.fasta"
  tree_ranks: ["order","family","genus","species"]
epa-ng:
  model: "GTR+F+I+I+R10"
```

## Run workflow
```bash
snakemake -j 1 -rpk 
```

### Output
Main taxonomic output will be in `results/taxonomy/taxonomy.tsv`. 