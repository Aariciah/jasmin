This repo contains the code needed to run my thesis experiments.
It uses the code from https://github.com/laurensw75/kaldi_egs_CGN + an additional script by Siyuan Feng to train the model.
The model is evaluated using the Flemish code from https://github.com/syfengcuhk/jasmin with adaptations.

The Spoken Dutch Corpus and JASMIN-CGN corpus are needed for this.
Additionally, you need to install eSpeak-NG (https://github.com/espeak-ng/espeak-ng) and Phonemizer (https://github.com/bootphon/phonemizer).

Clone this code into kaldi/egs and move the CGN code to that same level (as it is now a folder in kaldi/egs/jasmin).

Make sure to change the paths to the right directories and files, there are quite a lot of them and most of them are static.

To train the triphones: kaldi_egs_CGN-master/s5/run.sh
To train the BLSTM: kaldi_egs_CGN-master/s5/local/chain/tuning/run_tdnn_blstm.sh

To test the model: jasmin/s5_vl/scripts_hpc/sbatch/jasmin.sh
To rescore with RNNLM: jasmin/s5_vl/scripts_hpc/sbatch/jasmin_rnnlm.sh

To get PER: Move the files from the PER folder to the folder where your decode folders exist (for me: kaldi/egs/kaldi_egs_CGN/s5/exp/chain_cleaned/tdnn_lstm1a_blstm_sp_ld5)

Then run run_per.sh
