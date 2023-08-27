#!/usr/bin/env python

from argparse import ArgumentParser
import pandas as pd
import sys


def main(args):
    suffixes = args.suffixes
    df1 = pd.read_csv(args.file1, sep="\t", index_col=0)
    df1.rename(columns=lambda x: x.lower(), inplace=True)
    df2 = pd.read_csv(args.file2, sep="\t", index_col=0)
    df2.rename(columns=lambda x: x.lower(), inplace=True)
    columns = []
    for x in df1.columns:
        if x in df2.columns:
            columns.append(x)
    df = pd.merge(df1.loc[:, columns], df2.loc[:, columns], left_index=True, right_index=True, suffixes=suffixes)
    tot = df.shape[0]
    res = {}
    mismatch = {}
    for column in columns:
        matchrows = df.loc[df[f"{column}{suffixes[0]}"]==df[f"{column}{suffixes[1]}"]]
        mismatchrows = df.loc[df[f"{column}{suffixes[0]}"] != df[f"{column}{suffixes[1]}"]]
        if args.ignore_unclassified:
            mismatchrows = mismatchrows.loc[(~mismatchrows[f"{column}{suffixes[0]}"].str.startswith("unclassified"))&(~mismatchrows[f"{column}{suffixes[1]}"].str.startswith("unclassified"))]
            matchrows = matchrows.loc[(~matchrows[f"{column}{suffixes[0]}"].str.startswith("unclassified")) & (
                ~matchrows[f"{column}{suffixes[1]}"].str.startswith("unclassified"))]
        if mismatchrows.shape[0] > 0:
            mismatchstats = mismatchrows.groupby([f"{column}{suffixes[0]}", f"{column}{suffixes[1]}"]).size().reset_index()
            mismatchstats.rename(columns={0: 'n'}, inplace=True)
            mismatch[column] = mismatchstats
        res[column] = {'match': matchrows.shape[0], 'mismatch': mismatchrows.shape[0]}
    res_df = pd.DataFrame(res)
    res_percent_df = res_df.div(res_df.sum())*100
    res_df = pd.merge(res_df, res_percent_df, left_index=True, right_index=True, suffixes=["", "_%"])
    res_df = res_df.round(2)
    res_df.to_csv(sys.stdout, sep="\t")
    if args.outdir:
        for key, df in mismatch.items():
            f=f"{args.outdir}/mismatch_{key}.tsv"
            df.sort_values("n", ascending=False).to_csv(f, sep="\t", index=False)



if __name__ == "__main__":
    parser = ArgumentParser()
    parser.add_argument("file1", type=str,
                        help="Taxfile 1")
    parser.add_argument("file2", type=str,
                        help="Taxfile 2")
    parser.add_argument("--suffixes", nargs="+", default=["_1", "_2"],
                        help="Suffixes to add to duplicate columns")
    parser.add_argument("--outdir", type=str,
                        help="Write detailed mismatch results to outdir")
    parser.add_argument("--ignore_unclassified", action="store_true",
                        help="Ignore unclassified ASVs when comparing at each rank")
    args = parser.parse_args()
    main(args)