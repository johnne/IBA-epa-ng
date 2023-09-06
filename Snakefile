import os


configfile: "config.yml"


TREE = config["input"]["reference_tree"]
REF_MSA = config["input"]["reference_msa"]
QRY = config["input"]["query"]

ref_name = os.path.splitext(os.path.basename(TREE))[0]


rule all:
    input:
        expand(
            "results/taxonomy/{ref}/{run}/taxonomy.tsv",
            run=config["run"],
            ref=ref_name,
        ),
        expand(
            "results/taxonomy/{ref}/{run}/config.yml", run=config["run"], ref=ref_name
        ),


rule nexus2newick:
    output:
        "results/ref_tree/{ref}.nwk",
    input:
        config["input"]["reference_tree"],
    log:
        "logs/conversions/nexus2newick.{ref}.log",
    shell:
        """
        python src/nexus2newick.py {input} {output} >{log} 2>&1
        """


def ref_tree(wildcards):
    if config["input"]["reference_tree_format"] == "nexus":
        return rules.nexus2newick.output[0]
    elif config["input"]["reference_tree_format"] == "newick":
        return config["reference_tree"]


rule extract_ref_taxonomy:
    output:
        "results/ref_taxonomy/{ref}_taxon_file.tsv",
    input:
        ref_tree,
    log:
        "logs/extract_ref_taxonomy.{ref}.log",
    params:
        ranks=config["input"]["tree_ranks"],
    shell:
        """
        python src/extract_ref_taxonomy.py {input} {output} --ranks {params.ranks} >{log} 2>&1
        """


rule nexus2fasta:
    output:
        "results/ref_aln/{ref}.fasta",
    input:
        config["input"]["reference_msa"],
    log:
        "logs/conversion/nexus2fasta.{ref}.log",
    shell:
        """
        python src/convertalign.py {input} nexus {output} fasta >{log} 2>&1
        """


def ref_msa(wildcards):
    if config["input"]["reference_msa_format"] == "nexus":
        return rules.nexus2fasta.output[0]
    elif config["input"]["reference_msa_format"] == "fasta":
        return config["input"]["reference_msa"]


rule hmm_build:
    output:
        "results/ref_aln/{ref}.fasta.hmm",
    input:
        ref_msa,
    log:
        "logs/hmmbuild/{ref}.log",
    shell:
        """
        hmmbuild {output} {input} > {log} 2>&1
        """


rule hmm_align:
    output:
        "results/hmmalign/{ref}.{run}.fasta",
    input:
        hmm=rules.hmm_build.output,
        qry=QRY,
        ref_msa=ref_msa,
    log:
        "logs/hmmalign/hmmalign.{ref}.{run}.log",
    conda:
        "envs/hmmer.yml"
    shell:
        """
        hmmalign --trim --mapali {input.ref_msa} --outformat afa -o {output} {input.hmm} {input.qry} > {log} 2>&1
        """


rule split_aln:
    output:
        ref_msa="results/hmmalign/{run}/{ref}.fasta",
        qry_msa="results/hmmalign/{run}/query.{ref}.fasta",
    input:
        ref_msa=ref_msa,
        msa=rules.hmm_align.output,
    log:
        "logs/epa-ng/split{ref}.{run}.log",
    params:
        outdir=lambda wildcards, output: os.path.dirname(output.ref_msa),
    shell:
        """
        epa-ng --redo --out-dir {params.outdir} --split {input.ref_msa} {input.msa} > {log} 2>&1
        mv {params.outdir}/query.fasta {output.qry_msa}
        mv {params.outdir}/reference.fasta {output.ref_msa}
        """


rule raxml_evaluate:
    output:
        "results/raxml-ng/{run}/{ref}/info.raxml.bestModel",
    input:
        tree=rules.nexus2newick.output,
        msa=rules.split_aln.output.ref_msa,
    log:
        "logs/raxml-ng/raxml-ng.{run}.{ref}.log",
    params:
        model=config["epa-ng"]["model"],
        prefix=lambda wildcards, output: os.path.dirname(output[0]) + "/info",
    shell:
        """
        raxml-ng --evaluate --msa {input.msa} --tree {input.tree} --prefix {params.prefix} --model {params.model} >{log} 2>&1
        """


rule epa_ng:
    output:
        "results/epa-ng/{ref}/{run}/epa_result.jplace",
    input:
        qry=rules.split_aln.output.qry_msa,
        ref_msa=rules.split_aln.output.ref_msa,
        ref_tree=ref_tree,
        info=rules.raxml_evaluate.output,
    log:
        "logs/epa-ng/{ref}/epa-ng.{run}.log",
    params:
        outdir=lambda wildcards, output: os.path.dirname(output[0]),
    threads: 4
    shell:
        """
        epa-ng --redo -T {threads} --tree {input.ref_tree} --ref-msa {input.ref_msa} \
            --query {input.qry} --out-dir {params.outdir} --model {input.info} >{log} 2>&1
        """


rule gappa_assign:
    output:
        "results/gappa/{ref}/{run}/per_query.tsv",
    input:
        json=rules.epa_ng.output,
        taxonfile=rules.extract_ref_taxonomy.output,
    log:
        "logs/gappa/{ref}/gappa.{run}.log",
    params:
        ranks_string="|".join(config["input"]["tree_ranks"]),
        outdir=lambda wildcards, output: os.path.dirname(output[0]),
    threads: 4
    shell:
        """
        gappa examine assign --threads {threads} --out-dir {params.outdir} \
            --jplace-path {input.json} --taxon-file {input.taxonfile} \
            --ranks-string '{params.ranks_string}' --per-query-results \
            --best-hit --allow-file-overwriting > {log} 2>&1
        """


rule gappa2taxdf:
    output:
        "results/taxonomy/{ref}/{run}/taxonomy.tsv",
    input:
        rules.gappa_assign.output[0],
    params:
        ranks=config["input"]["tree_ranks"],
    shell:
        """
        python src/gappa2taxdf.py {input} {output} --ranks {params.ranks} 
        """


rule write_config:
    output:
        "results/taxonomy/{ref}/{run}/config.yml",
    run:
        import yaml

        with open(output[0], "w") as fhout:
            yaml.safe_dump(config, fhout, default_flow_style=False, sort_keys=False)
