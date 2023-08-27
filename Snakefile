import os


configfile: "config.yml"


TREE = config["input"]["reference_tree"]
REF_MSA = config["input"]["reference_msa"]
QRY = config["input"]["query"]


rule all:
    input:
        "results/taxonomy/taxonomy.tsv",


rule nexus2newick:
    output:
        "results/ref_tree/backbone.nwk",
    input:
        TREE,
    log:
        "logs/conversions/nexus2newick.log",
    shell:
        """
        python src/nexus2newick.py {input} {output} >{log} 2>&1
        """


rule extract_ref_taxonomy:
    output:
        "results/ref_taxonomy/taxon_file.tsv",
    input:
        rules.nexus2newick.output,
    log:
        "logs/extract_ref_taxonomy.log",
    params:
        ranks=config["input"]["tree_ranks"],
    shell:
        """
        python src/extract_ref_taxonomy.py {input} {output} --ranks {params.ranks} >{log} 2>&1
        """


rule nexus2fasta:
    output:
        "results/ref_aln/ref.fasta",
    input:
        REF_MSA,
    log:
        "logs/conversion/nexus2fasta.log",
    shell:
        """
        python src/convertalign.py {input} nexus {output} fasta >{log} 2>&1
        """


rule hmm_build:
    output:
        "results/ref_aln/ref.fasta.hmm",
    input:
        rules.nexus2fasta.output,
    log:
        "logs/hmmbuild/ref.aln.log",
    shell:
        """
        hmmbuild {output} {input} > {log} 2>&1
        """


rule hmm_align:
    output:
        "results/hmmalign/qry_ref.fasta",
    input:
        hmm=rules.hmm_build.output,
        qry=QRY,
        ref_msa=rules.nexus2fasta.output,
    log:
        "logs/hmmalign/hmmalign.log",
    conda:
        "envs/hmmer.yml"
    shell:
        """
        hmmalign --trim --mapali {input.ref_msa} --outformat afa -o {output} {input.hmm} {input.qry} > {log} 2>&1
        """


rule split_aln:
    output:
        ref_msa="results/hmmalign/reference.fasta",
        qry_msa="results/hmmalign/query.fasta",
    input:
        ref_msa=rules.nexus2fasta.output,
        msa=rules.hmm_align.output,
    log:
        "logs/epa-ng/split.log",
    params:
        outdir=lambda wildcards, output: os.path.dirname(output.ref_msa),
    shell:
        """
        epa-ng --out-dir {params.outdir} --split {input.ref_msa} {input.msa} > {log} 2>&1
        """


rule raxml_evaluate:
    output:
        "results/raxml-ng/info.raxml.bestModel",
    input:
        tree=rules.nexus2newick.output,
        msa=rules.split_aln.output.ref_msa,
    log:
        "logs/raxml-ng/raxml-ng.log",
    params:
        model=config["epa-ng"]["model"],
        prefix=lambda wildcards, output: os.path.dirname(output[0]) + "/info",
    shell:
        """
        raxml-ng --evaluate --msa {input.msa} --tree {input.tree} --prefix {params.prefix} --model {params.model} >{log} 2>&1
        """


rule epa_ng:
    output:
        "results/epa-ng/epa_result.jplace",
    input:
        qry=rules.split_aln.output.qry_msa,
        ref_msa=rules.split_aln.output.ref_msa,
        ref_tree=rules.nexus2newick.output,
        info=rules.raxml_evaluate.output,
    log:
        "logs/epa-ng/epa-ng.log",
    params:
        #model = config["epa-ng"]["model"],
        outdir=lambda wildcards, output: os.path.dirname(output[0]),
    threads: 4
    shell:
        """
        epa-ng --redo -T {threads} --tree {input.ref_tree} --ref-msa {input.ref_msa} \
            --query {input.qry} --out-dir {params.outdir} --model {input.info} >{log} 2>&1
        """


rule gappa_assign:
    output:
        "results/gappa/per_query.tsv",
    input:
        json=rules.epa_ng.output,
        taxonfile=rules.extract_ref_taxonomy.output,
    log:
        "logs/gappa/gappa.log",
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
        "results/taxonomy/taxonomy.tsv",
    input:
        rules.gappa_assign.output[0],
    params:
        ranks=config["input"]["tree_ranks"],
    shell:
        """
        python src/gappa2taxdf.py --ranks {params.ranks} {input} {output}
        """