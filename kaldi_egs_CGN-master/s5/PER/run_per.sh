#!/usr/bin/env bash

#for each directory ending in epoch20 (which are those after RNNLM rescoring)
#we want to get the WER file with the best LMWT, then phonemize the ASR hypothesis of that file
#then for the phonemized file we want to get the PER
#After getting all the PER files, we want to put the misrecognitions all in 1 file for better overview
#It prints the name of the directory and then the last 70 lines of the file
#It will likely print more lines than necessary but it works
touch misrecognitions.txt

for d in *epoch20/; do
	echo "$d"
	./get_lmwt_and_phonemize.sh $d all_utt2spk
	./get_per.sh $d/phonemes/test_filt_phonspk.txt $d/phonemes/test_hyp_phonspk.txt

	echo "This is directory $d" >> misrecognitions.txt	
	tail -n -70 $d/phonemes/test_hyp_phonspk.txt.dtl | cat >> misrecognitions.txt
	
done

