# Using EPA-NG for IBA

## Setup

1. Cloned https://github.com/ronquistlab/big-trees and symlinked 
   `data/train_data/` contents into `data/`
2. On Rackham, create a directory for data under 
   `/proj/snic2020-16-248/nobackup/IBA-epa-ng/data` and place `ASV_sequences.fna`
   (ASV sequences from swedish samples) there as well as `asv_taxa.lep.tsv` 
   (taxonomic assignments for Lepidoptera ASVs using SINTAX)
3. Extracted sequences for Lepidoptera using `seqtk` and stored as `data/lep.
   fasta`
4. Downloaded static binary for `papara` from https://sco.h-its.org/exelixis/web/software/papara/index.html 
   and placed under `bin/`. **However**, could not get papara to run 
   properly, neither as static binaries (on local mac, on rackham) nor when 
   compiled from source. Instead using `hmmalign` by first building a 
   profile from the reference MSA, then aligning the queries and including 
   the references from the original alignment. This alignment was then split 
   into references + queries using the `--split` flag in `epa-ng`.
5. Explicit model parameters for the tree were inferred using `raxml-ng` 

### Converting

Converted `data/lep_backbone_aln.nex` to phylip format:

```bash
python src/nexus2phylip.py data/lep_backbone_aln.nex data/lep_backbone_aln.phy
```
this stores a mapfile with original -> truncated labels as 
`data/lep_backbone_aln.phy.map`

Converted `data/backbone.nex` to newick format (renaming to truncated labels 
from previous step:

```bash
python src/nexus2newick.py data/backbone.nex data/backbone.nwk --mapfile data/lep_backbone_aln.phy.map
```

## Aligning the query sequences
