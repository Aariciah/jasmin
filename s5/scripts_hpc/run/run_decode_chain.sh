#!/bin/bash
# Copyright 2020 Siyuan Feng (Delft University of Technology)
# Based on a Dutch ASR system trained using CGN training material,
# Do decoding and scoring on JASMIN data
# JASMIN contains Dutch spoken by native children, non-native children, non-native adults and the native elderly
# JASMIN has two speech types, read speech (comp-q) and human-machine interaction (comp-p)
# JASMIN has NL Dutch and VL Dutch
# In jasmin/s5/ we focus on NL Dutch in Jasmin; go to jasmin/s5_vl/ for VL Dutch in Jasmin
stage=0
stop_stage=1
decode_iter=final
decode_stage=0
nj=1
lang="nl" # or 'vl'
debug_subset=
local_dir=data/local/data
cgn_root=/tudelft.net/staff-bulk/ewi/insy/SpeechLab/siyuanfeng/software/kaldi/egs/cgn/s5
cgn_model_spec= #"_comp_o" if you want to use a CGN ASR trained exclusively on CGN Read  material
use_gpu=false
num_threads_decode=1
extra_left_context=50
extra_right_context=50
frames_per_chunk=150
test_group_ID=1
test_gender=female
. utils/parse_options.sh
. ./cmd.sh
. ./path.sh
if [ ! "$decode_iter" =  "final" ]; then
  decode_iter_suffix="_${decode_iter}"
fi
cgn_asr_model=$cgn_root/exp/chain/tdnnf_related/aug_related/tdnn_blstm1a${cgn_model_spec}_sp_bi_epoch4_ld5
ivector_model=$cgn_root/exp/nnet3/extractor_aug_sp/
echo "$stage: $stop_stage: "
if $use_gpu; then
  gpu_suffix="_gpu"
else
  gpu_suffix=""
fi
echo "final.ie.id check: Should have identical information"
cat $ivector_model/final.ie.id
cat $cgn_asr_model/final.ie.id
# b42923b0810990e13ce1d3daa262c817
if [ $stage -le 0 ] && [ $stop_stage -gt 0 ]; then
  echo "$0: constructing data directories for read speech "
  # first a data/dir containing all ${lang} speech
  mkdir -p data/test_read_all || exit 1;
  cp $local_dir/test_${lang}_wav_comp_q.scp data/test_read_all/wav.scp
  cp $local_dir/segments_comp_q_${lang} data/test_read_all/segments
  cp $local_dir/utt2spk_comp_q_${lang} data/test_read_all/utt2spk
  cp $local_dir/spk2gender_${lang} data/test_read_all/spk2gender
  sed -i -e 's/M$/m/g' -e 's/F$/f/g' data/test_read_all/spk2gender
#  cp $local_dir/spk2age_${lang} data/test_read_all/spk2age
#  cp $local_dir/spk2group_${lang} data/test_read_all/spk2group
#  cp $local_dir/spk2dialectregion_${lang} data/test_read_all/spk2dialectregion
  cp $local_dir/text_comp_q_${lang} data/test_read_all/text
  utils/utt2spk_to_spk2utt.pl data/test_read_all/utt2spk > data/test_read_all/spk2utt
  utils/fix_data_dir.sh data/test_read_all
  utils/validate_data_dir.sh --no-feats data/test_read_all || exit 1
  # Create high-resolution MFCC features in a format same as in CGN.
  utils/copy_data_dir.sh data/test_read_all data/test_read_all_hires 
  steps/make_mfcc.sh --nj $nj --mfcc-config conf/mfcc_hires.conf \
    --cmd "$train_cmd" data/test_read_all_hires
  steps/compute_cmvn_stats.sh data/test_read_all_hires
  utils/fix_data_dir.sh data/test_read_all_hires 
fi

if [ $stage -le 1 ] && [ $stop_stage -gt 1 ]; then
  echo "$0: constructing data directories for human-machine interatction speech "
  # first a data/dir containing all ${lang} speech
  mkdir -p data/test_hmi_all || exit 1;
  cp $local_dir/test_${lang}_wav_comp_p.scp.sox data/test_hmi_all/wav.scp
  cp $local_dir/segments_comp_p_${lang} data/test_hmi_all/segments
  cp $local_dir/utt2spk_comp_p_${lang} data/test_hmi_all/utt2spk
  cp $local_dir/spk2gender_${lang} data/test_hmi_all/spk2gender
  sed -i -e 's/M$/m/g' -e 's/F$/f/g' data/test_hmi_all/spk2gender
#  cp $local_dir/spk2age_${lang} data/test_hmi_all/spk2age
#  cp $local_dir/spk2group_${lang} data/test_hmi_all/spk2group
#  cp $local_dir/spk2dialectregion_${lang} data/test_hmi_all/spk2dialectregion
  cp $local_dir/text_comp_p_${lang} data/test_hmi_all/text
  utils/utt2spk_to_spk2utt.pl data/test_hmi_all/utt2spk > data/test_hmi_all/spk2utt
  utils/fix_data_dir.sh data/test_hmi_all
  utils/validate_data_dir.sh --no-feats data/test_hmi_all || exit 1
  # 
  utils/copy_data_dir.sh data/test_hmi_all data/test_hmi_all_hires
  steps/make_mfcc.sh --nj $nj --mfcc-config conf/mfcc_hires.conf \
    --cmd "$train_cmd" data/test_hmi_all_hires
  steps/compute_cmvn_stats.sh data/test_hmi_all_hires
  utils/fix_data_dir.sh data/test_hmi_all_hires
fi



if [ $stage -le 2 ] && [ $stop_stage -gt 2 ]; then
  echo "For read speech, create gender-specific direncotries based on $local_dir/spklist_{male,female}_${lang}"
  # requires $local_dir/spk2gender_${lang}, which is generated by local/jasmin_data_prep.sh
  if [ ! -f $local_dir/spklist_female_${lang} ]; then
    python3 local/jasmin_select_speakers.py $local_dir/spk2gender_${lang} f $local_dir/spklist_female_${lang}.txt
    cut -d ' ' -f 1 $local_dir/spklist_female_${lang}.txt > $local_dir/spklist_female_${lang} 
  fi
  if [ ! -f $local_dir/spklist_male_${lang} ]; then
    python3 local/jasmin_select_speakers.py $local_dir/spk2gender_${lang} m $local_dir/spklist_male_${lang}.txt
    cut -d ' ' -f 1 $local_dir/spklist_male_${lang}.txt  > $local_dir/spklist_male_${lang}
  fi
  utils/subset_data_dir.sh --spk-list $local_dir/spklist_female_${lang} data/test_read_all_hires data/test_read_female_hires
  utils/subset_data_dir.sh --spk-list $local_dir/spklist_male_${lang}  data/test_read_all_hires data/test_read_male_hires
fi

if [ $stage -le 3 ] && [ $stop_stage -gt 3 ]; then
  echo "For read speech, create group-specific direncotries based on $local_dir/spklist_group{1,2,3,4,5}_${lang}"
  # requires $local_dir/spk2group_${lang}, which is generated by local/jasmin_data_prep.sh
  for group_id in 1 2 3 4 5; do
    if [ ! -f $local_dir/spklist_group${group_id}_${lang} ]; then
      python3 local/jasmin_select_speakers.py $local_dir/spk2group_${lang} $group_id $local_dir/spklist_group${group_id}_${lang}.txt
      cut -d ' ' -f 1 $local_dir/spklist_group${group_id}_${lang}.txt > $local_dir/spklist_group${group_id}_${lang}
    fi
    utils/subset_data_dir.sh --spk-list $local_dir/spklist_group${group_id}_${lang}  data/test_read_all_hires data/test_read_group${group_id}_hires
  done
  # next, create gender-specific sub-dirs based on group-wise dirs
  for group_id in 1 2 3 4 5; do
    for gender_label in female male; do
      utils/subset_data_dir.sh --spk-list $local_dir/spklist_${gender_label}_${lang} data/test_read_group${group_id}_hires data/test_read_group${group_id}_${gender_label}_hires 
    done
  done
fi

if [ $stage -le 4 ] && [ $stop_stage -gt 4 ]; then
  echo "For HMI Speech, create gender-specific direncotries based on $local_dir/spklist_{male,female}_${lang}"
  if [ ! -f $local_dir/spklist_female_${lang} ]; then
    python3 local/jasmin_select_speakers.py $local_dir/spk2gender_${lang} f $local_dir/spklist_female_${lang}.txt
    cut -d ' ' -f 1 $local_dir/spklist_female_${lang}.txt > $local_dir/spklist_female_${lang} 
  fi
  if [ ! -f $local_dir/spklist_male_${lang} ]; then
    python3 local/jasmin_select_speakers.py $local_dir/spk2gender_${lang} m $local_dir/spklist_male_${lang}.txt
    cut -d ' ' -f 1 $local_dir/spklist_male_${lang}.txt  > $local_dir/spklist_male_${lang}
  fi
  utils/subset_data_dir.sh --spk-list $local_dir/spklist_female_${lang} data/test_hmi_all_hires data/test_hmi_female_hires
  utils/subset_data_dir.sh --spk-list $local_dir/spklist_male_${lang}  data/test_hmi_all_hires data/test_hmi_male_hires
fi

if [ $stage -le 5 ] && [ $stop_stage -gt 5 ]; then
  echo "For HMI speech, create group-specific direncotries based on $local_dir/spklist_group{1,2,3,4,5}_${lang}"
  # requires $local_dir/spk2group_${lang}, which is generated by local/jasmin_data_prep.sh
  for group_id in 1 2 3 4 5; do
    if [ ! -f $local_dir/spklist_group${group_id}_${lang} ]; then
      python3 local/jasmin_select_speakers.py $local_dir/spk2group_${lang} $group_id $local_dir/spklist_group${group_id}_${lang}.txt
      cut -d ' ' -f 1 $local_dir/spklist_group${group_id}_${lang}.txt > $local_dir/spklist_group${group_id}_${lang}
    fi
    utils/subset_data_dir.sh --spk-list $local_dir/spklist_group${group_id}_${lang}  data/test_hmi_all_hires data/test_hmi_group${group_id}_hires
  done
  # next, create gender-specific sub-dirs based on group-wise dirs
  for group_id in 1 2 3 4 5; do
    for gender_label in female male; do
      utils/subset_data_dir.sh --spk-list $local_dir/spklist_${gender_label}_${lang} data/test_hmi_group${group_id}_hires data/test_hmi_group${group_id}_${gender_label}_hires
    done
  done

fi
if [ $stage -le 6 ] && [ $stop_stage -gt 6 ]; then
  echo "For Read speech, create dialect-region-specific directories based on $local_dir/spklist_dialectretion_N{1,2,3,4}"
  for dialect_region_label in 1 2 3 4; do
    if [ ! -f $local_dir/spklist_dialectregion_N${dialect_region_label} ]; then
      python3 local/jasmin_select_speakers_nl_dialect_region.py $local_dir/spk2dialectregion_${lang} "N${dialect_region_label}" $local_dir/spklist_dialectregion_N${dialect_region_label}.txt
      cut -d ' ' -f 1 $local_dir/spklist_dialectregion_N${dialect_region_label}.txt > $local_dir/spklist_dialectregion_N${dialect_region_label}
    fi
    # only for groups 1 2 and 5 dialect region labels apply (native only)
    for group_id in 1 2 5; do
      utils/subset_data_dir.sh --spk-list $local_dir/spklist_dialectregion_N${dialect_region_label} data/test_read_group${group_id}_hires data/test_read_group${group_id}_N${dialect_region_label}_hires
    done
  done
fi
if [ $stage -le 7 ] && [ $stop_stage -gt 7 ]; then
  echo "For HMI speech, create dialect-region-specific directories based on $local_dir/spklist_dialectretion_N{1,2,3,4}"
  for dialect_region_label in 1 2 3 4; do
    if [ ! -f $local_dir/spklist_dialectregion_N${dialect_region_label} ]; then
      python3 local/jasmin_select_speakers_nl_dialect_region.py $local_dir/spk2dialectregion_${lang} "N${dialect_region_label}" $local_dir/spklist_dialectregion_N${dialect_region_label}.txt
      cut -d ' ' -f 1 $local_dir/spklist_dialectregion_N${dialect_region_label}.txt > $local_dir/spklist_dialectregion_N${dialect_region_label}
    fi
    # only for groups 1 2 and 5 dialect region labels apply (native only)
    for group_id in 1 2 5; do
      utils/subset_data_dir.sh --spk-list $local_dir/spklist_dialectregion_N${dialect_region_label} data/test_hmi_group${group_id}_hires data/test_hmi_group${group_id}_N${dialect_region_label}_hires
    done
  done
fi
if [ $stage -le 8 ] && [ $stop_stage -gt 8 ]; then
  echo "For Read speech nonnative adults, create CEF-specific directories based on $local_dir/spklist_CEF_{A1,A2,B1}"
  for CEF_label in A1 A2 B1 ; do
    if [ ! -f $local_dir/spklist_CEF_${CEF_label} ]; then
      python3 local/jasmin_select_speakers_nl_dialect_region.py $local_dir/spk2CEF_${lang} "${CEF_label}" $local_dir/spklist_CEF_${CEF_label}.txt
      cut -d ' ' -f 1 $local_dir/spklist_CEF_${CEF_label}.txt > $local_dir/spklist_CEF_${CEF_label}
    fi
    # only for groups 4 dialect region labels apply (non native adults only)
    for group_id in 4; do
      utils/subset_data_dir.sh --spk-list $local_dir/spklist_CEF_${CEF_label} data/test_read_group${group_id}_hires data/test_read_group${group_id}_${CEF_label}_hires
    done
  done
fi

if [ $stage -le 9 ] && [ $stop_stage -gt 9 ]; then
  echo "For HMI speech nonnative adults, create CEF-specific directories based on $local_dir/spklist_CEF_{A1,A2,B1}"
  for CEF_label in A1 A2 B1 ; do
    if [ ! -f $local_dir/spklist_CEF_${CEF_label} ]; then
      python3 local/jasmin_select_speakers_nl_dialect_region.py $local_dir/spk2CEF_${lang} "${CEF_label}" $local_dir/spklist_CEF_${CEF_label}.txt
      cut -d ' ' -f 1 $local_dir/spklist_CEF_${CEF_label}.txt > $local_dir/spklist_CEF_${CEF_label}
    fi
    # only for groups 4 dialect region labels apply (non native adults only)
    for group_id in 4; do
      utils/subset_data_dir.sh --spk-list $local_dir/spklist_CEF_${CEF_label} data/test_hmi_group${group_id}_hires data/test_hmi_group${group_id}_${CEF_label}_hires
    done
  done
fi
if [ $stage -le 11 ] && [ $stop_stage -gt 11 ]; then
  echo "Extracting ivectors: For Read speech, all data "
  input_data=data/test_read_all_hires
  steps/online/nnet2/extract_ivectors_online.sh --cmd "$train_cmd" --nj $nj $input_data $ivector_model exp/nnet3/ivectors_cgn_aug_sp_test_read_all  
 
fi
if [ $stage -le 12 ] && [ $stop_stage -gt 12 ]; then
  echo "Extracting ivectors: For HMI speech, all data "
  input_data=data/test_hmi_all_hires
  steps/online/nnet2/extract_ivectors_online.sh --cmd "$train_cmd" --nj $nj $input_data $ivector_model exp/nnet3/ivectors_cgn_aug_sp_test_hmi_all

fi
if [ $stage -le 21 ] && [ $stop_stage -gt 21 ]; then
  echo "Decoding...: For Read speech, all data"
  input_data=data/test_read_all_hires${debug_subset}
  input_ivector=exp/nnet3/ivectors_cgn_aug_sp_test_read_all
  output_suffix=test_read_all${debug_subset}
  # ref. cgn/s5/local/chain/tuning/data_aug/run_tdnn_blstm_1a.sh
  steps/nnet3/decode.sh --num-threads $num_threads_decode --nj $nj --cmd "$decode_cmd" --acwt 1.0 --post-decode-acwt 10.0  --stage $decode_stage  \
    --online-ivector-dir $input_ivector \
    --scoring-opts "--min-lmwt 5 " \
    --use-gpu $use_gpu \
    --extra-left-context $extra_left_context \
    --extra-right-context $extra_right_context \
    --frames-per-chunk $frames_per_chunk \
    $cgn_asr_model/graph $input_data $cgn_asr_model/decode_jasmin_${lang}_${output_suffix}${gpu_suffix} || exit 1;
  steps/lmrescore_const_arpa.sh --cmd "$decode_cmd" $cgn_root/data/lang_s_test_{tgpr,fgconst} \
    $input_data $cgn_asr_model/decode_jasmin_${lang}_${output_suffix}${gpu_suffix} $cgn_asr_model/decode_jasmin_${lang}_${output_suffix}${gpu_suffix}_rescore || exit 1
fi

if [ $stage -le 22 ] && [ $stop_stage -gt 22 ]; then
  echo "Decoding...: For HMI speech, all data"
  input_data=data/test_hmi_all_hires${debug_subset}
  input_ivector=exp/nnet3/ivectors_cgn_aug_sp_test_hmi_all
  output_suffix=test_hmi_all${debug_subset}
  # ref. cgn/s5/local/chain/tuning/data_aug/run_tdnn_blstm_1a.sh
  steps/nnet3/decode.sh --num-threads $num_threads_decode --nj $nj --cmd "$decode_cmd" --acwt 1.0 --post-decode-acwt 10.0 --stage $decode_stage \
    --online-ivector-dir $input_ivector \
    --scoring-opts "--min-lmwt 5 " \
    --use-gpu $use_gpu \
    --extra-left-context $extra_left_context \
    --extra-right-context $extra_right_context \
    --frames-per-chunk $frames_per_chunk \
    $cgn_asr_model/graph $input_data $cgn_asr_model/decode_jasmin_${lang}_${output_suffix}${gpu_suffix} || exit 1;
  steps/lmrescore_const_arpa.sh --cmd "$decode_cmd" $cgn_root/data/lang_s_test_{tgpr,fgconst} \
    $input_data $cgn_asr_model/decode_jasmin_${lang}_${output_suffix}${gpu_suffix} $cgn_asr_model/decode_jasmin_${lang}_${output_suffix}${gpu_suffix}_rescore || exit 1
fi

if [ $stage -le 31 ] && [ $stop_stage -gt 31 ]; then
  echo "Decoding...: For Read speech, Group specific data"
  input_data=data/test_read_group${test_group_ID}_hires${debug_subset}
  input_ivector=exp/nnet3/ivectors_cgn_aug_sp_test_read_all
  output_suffix=test_read_group${test_group_ID}${debug_subset}
  # ref. cgn/s5/local/chain/tuning/data_aug/run_tdnn_blstm_1a.sh
  steps/nnet3/decode.sh --num-threads $num_threads_decode --nj $nj --cmd "$decode_cmd" --acwt 1.0 --post-decode-acwt 10.0  --stage $decode_stage  \
    --online-ivector-dir $input_ivector \
    --scoring-opts "--min-lmwt 5 " \
    --iter $decode_iter \
    --use-gpu $use_gpu \
    --extra-left-context $extra_left_context \
    --extra-right-context $extra_right_context \
    --frames-per-chunk $frames_per_chunk \
    $cgn_asr_model/graph $input_data $cgn_asr_model/decode_jasmin_${lang}_${output_suffix}${gpu_suffix}${decode_iter_suffix} || exit 1;
  steps/lmrescore_const_arpa.sh --cmd "$decode_cmd" $cgn_root/data/lang_s_test_{tgpr,fgconst} \
    $input_data $cgn_asr_model/decode_jasmin_${lang}_${output_suffix}${gpu_suffix} $cgn_asr_model/decode_jasmin_${lang}_${output_suffix}${gpu_suffix}_rescore || exit 1
fi

if [ $stage -le 32 ] && [ $stop_stage -gt 32 ]; then
  echo "Decoding...: For HMI speech, Group specific data"
  input_data=data/test_hmi_group${test_group_ID}_hires${debug_subset}
  input_ivector=exp/nnet3/ivectors_cgn_aug_sp_test_hmi_all
  output_suffix=test_hmi_group${test_group_ID}${debug_subset}
  # ref. cgn/s5/local/chain/tuning/data_aug/run_tdnn_blstm_1a.sh
  steps/nnet3/decode.sh --num-threads $num_threads_decode --nj $nj --cmd "$decode_cmd" --acwt 1.0 --post-decode-acwt 10.0  --stage $decode_stage  \
    --online-ivector-dir $input_ivector \
    --scoring-opts "--min-lmwt 5 " \
    --use-gpu $use_gpu \
    --extra-left-context $extra_left_context \
    --extra-right-context $extra_right_context \
    --frames-per-chunk $frames_per_chunk \
    $cgn_asr_model/graph $input_data $cgn_asr_model/decode_jasmin_${lang}_${output_suffix}${gpu_suffix} || exit 1;
  steps/lmrescore_const_arpa.sh --cmd "$decode_cmd" $cgn_root/data/lang_s_test_{tgpr,fgconst} \
    $input_data $cgn_asr_model/decode_jasmin_${lang}_${output_suffix}${gpu_suffix} $cgn_asr_model/decode_jasmin_${lang}_${output_suffix}${gpu_suffix}_rescore || exit 1
fi

if [ $stage -le 33 ] && [ $stop_stage -gt 33 ]; then
  echo "Decoding...: For Read speech, gender-specific data"
  input_data=data/test_read_${test_gender}_hires${debug_subset}
  input_ivector=exp/nnet3/ivectors_cgn_aug_sp_test_read_all
  output_suffix=test_read_${test_gender}${debug_subset}
  steps/nnet3/decode.sh --num-threads $num_threads_decode --nj $nj --cmd "$decode_cmd" --acwt 1.0 --post-decode-acwt 10.0  --stage $decode_stage  \
    --online-ivector-dir $input_ivector \
    --scoring-opts "--min-lmwt 5 " \
    --use-gpu $use_gpu \
    --extra-left-context $extra_left_context \
    --extra-right-context $extra_right_context \
    --frames-per-chunk $frames_per_chunk \
    $cgn_asr_model/graph $input_data $cgn_asr_model/decode_jasmin_${lang}_${output_suffix}${gpu_suffix} || exit 1;
  steps/lmrescore_const_arpa.sh --cmd "$decode_cmd" $cgn_root/data/lang_s_test_{tgpr,fgconst} \
    $input_data $cgn_asr_model/decode_jasmin_${lang}_${output_suffix}${gpu_suffix} $cgn_asr_model/decode_jasmin_${lang}_${output_suffix}${gpu_suffix}_rescore || exit 1  

fi

if [ $stage -le 34 ] && [ $stop_stage -gt 34 ]; then
  echo "Decoding...: For HMI speech, gender-specific data"
  input_data=data/test_hmi_${test_gender}_hires${debug_subset}
  input_ivector=exp/nnet3/ivectors_cgn_aug_sp_test_hmi_all
  output_suffix=test_hmi_${test_gender}${debug_subset}
  steps/nnet3/decode.sh --num-threads $num_threads_decode --nj $nj --cmd "$decode_cmd" --acwt 1.0 --post-decode-acwt 10.0  --stage $decode_stage  \
    --online-ivector-dir $input_ivector \
    --scoring-opts "--min-lmwt 5 " \
    --use-gpu $use_gpu \
    --extra-left-context $extra_left_context \
    --extra-right-context $extra_right_context \
    --frames-per-chunk $frames_per_chunk \
    $cgn_asr_model/graph $input_data $cgn_asr_model/decode_jasmin_${lang}_${output_suffix}${gpu_suffix} || exit 1;
  steps/lmrescore_const_arpa.sh --cmd "$decode_cmd" $cgn_root/data/lang_s_test_{tgpr,fgconst} \
    $input_data $cgn_asr_model/decode_jasmin_${lang}_${output_suffix}${gpu_suffix} $cgn_asr_model/decode_jasmin_${lang}_${output_suffix}${gpu_suffix}_rescore || exit 1

fi

if [ $stage -le 35 ] && [ $stop_stage -gt 35 ]; then
  # Gender-specific on group-wise Read data
  for gender_label in female male; do
    input_data=data/test_read_group${test_group_ID}_${gender_label}_hires${debug_subset}
    input_ivector=exp/nnet3/ivectors_cgn_aug_sp_test_read_all
    output_suffix=test_read_group${test_group_ID}_${gender_label}${debug_subset}
    # ref. cgn/s5/local/chain/tuning/data_aug/run_tdnn_blstm_1a.sh
    steps/nnet3/decode.sh --num-threads $num_threads_decode --nj $nj --cmd "$decode_cmd" --acwt 1.0 --post-decode-acwt 10.0  --stage $decode_stage  \
      --online-ivector-dir $input_ivector \
      --scoring-opts "--min-lmwt 5 " \
      --iter $decode_iter \
      --use-gpu $use_gpu \
      --extra-left-context $extra_left_context \
      --extra-right-context $extra_right_context \
      --frames-per-chunk $frames_per_chunk \
      $cgn_asr_model/graph $input_data $cgn_asr_model/decode_jasmin_${lang}_${output_suffix}${gpu_suffix}${decode_iter_suffix} || exit 1;
    steps/lmrescore_const_arpa.sh --cmd "$decode_cmd" $cgn_root/data/lang_s_test_{tgpr,fgconst} \
    $input_data $cgn_asr_model/decode_jasmin_${lang}_${output_suffix}${gpu_suffix} $cgn_asr_model/decode_jasmin_${lang}_${output_suffix}${gpu_suffix}_rescore || exit 1

  done
fi

if [ $stage -le 36 ] && [ $stop_stage -gt 36 ]; then
  # Gender-specific on group-wise HMI data
  for gender_label in female male; do
    input_data=data/test_hmi_group${test_group_ID}_${gender_label}_hires${debug_subset}
    input_ivector=exp/nnet3/ivectors_cgn_aug_sp_test_hmi_all
    output_suffix=test_hmi_group${test_group_ID}_${gender_label}${debug_subset}
    # ref. cgn/s5/local/chain/tuning/data_aug/run_tdnn_blstm_1a.sh
    steps/nnet3/decode.sh --num-threads $num_threads_decode --nj $nj --cmd "$decode_cmd" --acwt 1.0 --post-decode-acwt 10.0  --stage $decode_stage  \
      --online-ivector-dir $input_ivector \
      --scoring-opts "--min-lmwt 5 " \
      --iter $decode_iter \
      --use-gpu $use_gpu \
      --extra-left-context $extra_left_context \
      --extra-right-context $extra_right_context \
      --frames-per-chunk $frames_per_chunk \
      $cgn_asr_model/graph $input_data $cgn_asr_model/decode_jasmin_${lang}_${output_suffix}${gpu_suffix}${decode_iter_suffix} || exit 1;
    steps/lmrescore_const_arpa.sh --cmd "$decode_cmd" $cgn_root/data/lang_s_test_{tgpr,fgconst} \
    $input_data $cgn_asr_model/decode_jasmin_${lang}_${output_suffix}${gpu_suffix} $cgn_asr_model/decode_jasmin_${lang}_${output_suffix}${gpu_suffix}_rescore || exit 1

  done
fi

if [ $stage -le 41 ] && [ $stop_stage -gt 41 ]; then
  echo "Decoding...: For Read Speech, region within each Group-specific data"
  # Groups 1, 2, and 5 contain N1, N2, N3, N4
  # Groups 4 contains A1, A2 and B1
  for group_id in 1 2 5; do
    for region_id in N1 N2 N3 N4; do
      input_data=data/test_read_group${group_id}_${region_id}_hires
      if [ -s $input_data/feats.scp ]; then
        input_ivector=exp/nnet3/ivectors_cgn_aug_sp_test_read_all
        output_suffix=test_read_group${group_id}_${region_id}
        steps/nnet3/decode.sh --num-threads $num_threads_decode --nj $nj --cmd "$decode_cmd" --acwt 1.0 --post-decode-acwt 10.0  --stage $decode_stage  \
        --online-ivector-dir $input_ivector \
        --scoring-opts "--min-lmwt 5 " \
        --use-gpu $use_gpu \
        --extra-left-context $extra_left_context \
        --extra-right-context $extra_right_context \
        --frames-per-chunk $frames_per_chunk \
        $cgn_asr_model/graph $input_data $cgn_asr_model/decode_jasmin_${lang}_${output_suffix}${gpu_suffix} || exit 1;
        steps/lmrescore_const_arpa.sh --cmd "$decode_cmd" $cgn_root/data/lang_s_test_{tgpr,fgconst} \
          $input_data $cgn_asr_model/decode_jasmin_${lang}_${output_suffix}${gpu_suffix}  $cgn_asr_model/decode_jasmin_${lang}_${output_suffix}${gpu_suffix}_rescore
      fi
    done
  done 
fi

if [ $stage -le 42 ] && [ $stop_stage -gt 42 ]; then
  echo "Decoding...: For HMI Speech, region within each Group-specific data"
  # Groups 1, 2, and 5 contain N1, N2, N3, N4
  # Groups 4 contains A1, A2 and B1
  for group_id in 1 2 5; do
    for region_id in N1 N2 N3 N4; do
      input_data=data/test_hmi_group${group_id}_${region_id}_hires
      if [ -s $input_data/feats.scp ]; then
        input_ivector=exp/nnet3/ivectors_cgn_aug_sp_test_hmi_all
        output_suffix=test_hmi_group${group_id}_${region_id}
        steps/nnet3/decode.sh --num-threads $num_threads_decode --nj $nj --cmd "$decode_cmd" --acwt 1.0 --post-decode-acwt 10.0  --stage $decode_stage  \
        --online-ivector-dir $input_ivector \
        --scoring-opts "--min-lmwt 5 " \
        --use-gpu $use_gpu \
        --extra-left-context $extra_left_context \
        --extra-right-context $extra_right_context \
        --frames-per-chunk $frames_per_chunk \
        $cgn_asr_model/graph $input_data $cgn_asr_model/decode_jasmin_${lang}_${output_suffix}${gpu_suffix} || exit 1;
        steps/lmrescore_const_arpa.sh --cmd "$decode_cmd" $cgn_root/data/lang_s_test_{tgpr,fgconst} \
          $input_data $cgn_asr_model/decode_jasmin_${lang}_${output_suffix}${gpu_suffix}  $cgn_asr_model/decode_jasmin_${lang}_${output_suffix}${gpu_suffix}_rescore
      fi
    done
  done
fi

if [ $stage -le 43 ] && [ $stop_stage -gt 43 ]; then
  echo "Decoding: Read speech, group 4 (non-native adults: CEF level)"
  group_id=4
  for CEF_label in A1 A2 B1; do
    input_data=data/test_read_group${group_id}_${CEF_label}_hires
    input_ivector=exp/nnet3/ivectors_cgn_aug_sp_test_read_all
    output_suffix=test_read_group${group_id}_${CEF_label}
    steps/nnet3/decode.sh --num-threads $num_threads_decode --nj $nj --cmd "$decode_cmd" --acwt 1.0 --post-decode-acwt 10.0  --stage $decode_stage  \
      --online-ivector-dir $input_ivector \
      --scoring-opts "--min-lmwt 5 " \
      --use-gpu $use_gpu \
      --extra-left-context $extra_left_context \
      --extra-right-context $extra_right_context \
      --frames-per-chunk $frames_per_chunk \
      $cgn_asr_model/graph $input_data $cgn_asr_model/decode_jasmin_${lang}_${output_suffix}${gpu_suffix} || exit 1;
    steps/lmrescore_const_arpa.sh --cmd "$decode_cmd" $cgn_root/data/lang_s_test_{tgpr,fgconst} \
      $input_data  $cgn_asr_model/decode_jasmin_${lang}_${output_suffix}${gpu_suffix} $cgn_asr_model/decode_jasmin_${lang}_${output_suffix}${gpu_suffix}_rescore
  done
fi

if [ $stage -le 44 ] && [ $stop_stage -gt 44 ]; then
  echo "Decoding: HMI speech, group 4 (non-native adults: CEF level)"
  group_id=4
  for CEF_label in A1 A2 B1; do
    input_data=data/test_hmi_group${group_id}_${CEF_label}_hires
    input_ivector=exp/nnet3/ivectors_cgn_aug_sp_test_hmi_all
    output_suffix=test_hmi_group${group_id}_${CEF_label}
    steps/nnet3/decode.sh --num-threads $num_threads_decode --nj $nj --cmd "$decode_cmd" --acwt 1.0 --post-decode-acwt 10.0  --stage $decode_stage  \
      --online-ivector-dir $input_ivector \
      --scoring-opts "--min-lmwt 5 " \
      --use-gpu $use_gpu \
      --extra-left-context $extra_left_context \
      --extra-right-context $extra_right_context \
      --frames-per-chunk $frames_per_chunk \
      $cgn_asr_model/graph $input_data $cgn_asr_model/decode_jasmin_${lang}_${output_suffix}${gpu_suffix} || exit 1;
    steps/lmrescore_const_arpa.sh --cmd "$decode_cmd" $cgn_root/data/lang_s_test_{tgpr,fgconst} \
      $input_data  $cgn_asr_model/decode_jasmin_${lang}_${output_suffix}${gpu_suffix} $cgn_asr_model/decode_jasmin_${lang}_${output_suffix}${gpu_suffix}_rescore
  done
fi


echo "$0: succeeded"
