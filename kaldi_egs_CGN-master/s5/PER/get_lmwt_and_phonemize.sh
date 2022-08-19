mkdir -p $1/hyp
mkdir -p $1/phonemes

/home/herygers/kaldi/egs/wsj/s5/utils/run.pl LMWT=4:17 custom_wer_test_LMWT.log \
    cat $1/scoring/LMWT.tra \| \
       /home/herygers/kaldi/egs/kaldi_egs_CGN/s5/utils/int2sym.pl -f 2- graph/words.txt \| /home/herygers/kaldi/egs/kaldi_egs_CGN/s5/local/filter_hyp.pl \> $1/hyp/test_hyp_LMWT.txt || exit 1;

BEST_LMWT=$(./best_wer_lmwt.py $1 4 17)
echo Using best LMWT of $BEST_LMWT
cat $1/hyp/test_hyp_$BEST_LMWT.txt > $1/hyp/test_hyp.txt

./get_speakers.py $2 $1/hyp/test_hyp.txt $1/scoring/test_filt.txt
cat $1/hyp/test_hyp.txt | ./trim_column.py | phonemize -l nl -p ' ' -w '' --preserve-empty-lines > $1/phonemes/test_hyp_phonemes.txt
cat $1/scoring/test_filt.txt | ./trim_column.py | phonemize -l nl -p ' ' -w '' --preserve-empty-lines > $1/phonemes/test_filt_phonemes.txt
./add_speakers.py $1/hyp/test_hyp.txt.speakers $1/phonemes/test_hyp_phonemes.txt $1/phonemes/test_hyp_phonspk.txt
./add_speakers.py $1/scoring/test_filt.txt.speakers $1/phonemes/test_filt_phonemes.txt $1/phonemes/test_filt_phonspk.txt
