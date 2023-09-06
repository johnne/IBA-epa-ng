# Using EPA-NG for IBA
This workflow performs phylogenetic placement of query sequences into a 
reference backbone tree using [EPA-NG](https://github.com/pierrebarbera/epa-ng) 
then assigns taxonomy to the queries using [GAPPA](https://github.com/lczech/gappa).

## Installation

- Clone this repository then create a conda environment using the 
`environment.yml` file:

```bash
conda env create -f environment.yml
conda activate IBA-epa-ng
```

- Install [raxml-ng](https://github.com/amkozlov/raxml-ng) by downloading 
  the appropriate binary from https://github.com/amkozlov/raxml-ng#installation-instructions. 
  Unzip the file and move the `raxml-ng` binary to `$CONDA_PREFIX/bin`. 
  Below is an example for version `1.2.0` on a linux platform:

```bash
version="1.2.0"
platform="linux_x86_64"
mv raxml-ng_v${version}_${platform}/epa-ng $CONDA_PREFIX/bin
```

## Configuration
The workflow takes parameters from a config file in yaml format. 

The default config is:
```yaml
# Give the configuration a name for downstream reference
run: "default"
# Set input options
input:
  reference_tree: "data/backbone.nex"
  reference_tree_format: "nexus"
  reference_msa: "data/lep_backbone_aln.nex"
  reference_msa_format: "nexus"
  query: "data/lep.fasta"
  tree_ranks: ["order","family","genus","species"]
  ref_taxonomy: ""
epa-ng:
  # Model used for the reference backbone
  model: "GTR+F+I+I+R10"
gappa:
  # Ratio by which LWR is split between annotations if an edge has two possible
  # annotations. Specifies the amount going to the proximal annotation. If not
  # set program will determine the ratio automatically from the 'distal length'
  # specified per placement.
  distribution-ratio: -1
  # For assignment of taxonomic labels to the reference tree, require this
  # consensus threshold. Example: if set to 0.6, and 60% of an inner node's
  # descendants share a taxonomic path, set that path at the inner node.
  consensus-thresh: 1
```

- The `run` config parameter allows you to set a name for a specific run, 
which allows you to run with different parameters and track the downstream 
results.
- Under `input` you specify the input files for this run:
  - `reference_tree`: reference backbone phylogeny
  - `reference_tree_format`: format of reference backbone, if 'nexus' the 
    phylogeny will be converted to newick
  - `reference_msa`: reference backbone alignment
  - `reference_msa_format`: format of reference backbone alignment. If 
    'nexus' the alignment will be converted to fasta
  - `query`: query sequences in fasta format
  - `tree_ranks`: ranks found in leaf names of reference backbone phylogeny. 
    Each leaf in the backbone should contain taxlabels separated by `_`, *e.g.* 
    `Trichoptera_Hydroptilidae_Palaeagapetus_nearcticus_KX292484_1` where 
    order="Trichoptera", family="Hydroptilidae", genus="Palaeagapetus". The 
    species name will be extracted from the last part in the leaf name.
  - `ref_taxonomy`: Supply a file mapping leaf names in the backbone tree to 
    taxonomic labels. This file must be tab-separated with two columns, the 
    first containing leaf names and the second a taxonomic string with 
    taxlabels separated by `;`, *e.g*:
    ```
    Trichoptera_Hydroptilidae_Palaeagapetus_nearcticus_KX292484_1   Trichoptera;Hydroptilidae;Palaeagapetus;Palaeagapetus_nearcticus_KX292484_1
    ```
- Under `epa-ng` you specify parameters for the epa-ng placement software.
  - `model`: Specify the model used to create the backbone phylogeny. 
    A RAxML info file is created for the backbone using RAxML-ng.
- Under `gappa` you specify parameters for the taxonomic assignment using 
  the gappa software:
  - `distribution-ratio`: A value between 0 and 1. This determines how the 
    LWR is split between annotations. If set to -1 (default), the gappa 
    software will determine a ratio automatically.
  - `consensus-thresh`: A value between 0 and 1. The consensus threshold 
    required to assign taxonomic labels. If set to 1 (default) all 
    descendants must share the same taxonomic path.
  

## Example setup

1. Reference tree data was obtained by cloning https://github.com/ronquistlab/big-trees
   and symlinking `data/train_data/` contents into `data/`.
2. On Rackham, create a directory for data under 
   `/proj/snic2020-16-248/nobackup/IBA-epa-ng/data` and place `ASV_sequences.fna`
   (ASV sequences from swedish samples) there as well as `asv_taxa.lep.tsv` 
   (taxonomic assignments for Lepidoptera ASVs using SINTAX)
3. Extracted sequences for Lepidoptera using `seqtk` and stored as `data/lep.
   fasta`
4. Create the conda environment from `environment.yml` and activate it


## Run workflow
```bash
snakemake -j 1 -rpk 
```

### Running on SLURM clusters

To run on a compute cluster with the SLURM workload manager, open up the 
`slurm/config.yaml` file and edit the line with `default-resources: 
"slurm_account=<your SLURM account>"` by changing `<your SLURM account>` to 
your actual slurm account. Then run the workflow as: 

```bash
snakemake --profile slurm 
```

### Output
Main taxonomic output will be in `"results/taxonomy/{ref}/{run}/taxonomy.tsv"`. 