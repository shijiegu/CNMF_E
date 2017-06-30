#!/bin/bash

#SBATCH -n 1
#SBATCH --cpus-per-task=8
#SBATCH --mem=200000
#SBATCH -t 0-10:00
#SBATCH --time-min=0-01:00
#SBATCH -o /net/feevault/data0/shared/EmilyShijieShared/BatchResult/6922FirstFewDaysForBatch/job_%A.out
#SBATCH -e /net/feevault/data0/shared/EmilyShijieShared/BatchResult/6922FirstFewDaysForBatch/job_%A.err
cd /net/feevault/data0/shared/EmilyShijieShared/BatchResult/6922FirstFewDaysForBatch/
module add mit/matlab/2016b
matlab -nodisplay -singleCompThread -r "addpath(genpath('/home/shijiegu/cnmf_e/'));\
load(fullfile('/net/feevault/data0/shared/EmilyShijieShared/BatchResult/6922FirstFewDaysForBatch/','LogisticscnmfeBatchVer.mat')); cnmfeBatchVer_ClusterPart "