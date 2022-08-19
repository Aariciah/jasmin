#!/usr/bin/env python
import argparse
from argparse import ArgumentParser, FileType

def main(arguments):
    parser = ArgumentParser()
    parser.add_argument("speakers_file", type=FileType("r", encoding="utf-8"), help="Concatenated utt2spk file")
    parser.add_argument("text_files", nargs="+", help="Input files with utterance IDs in the first column")
    args = parser.parse_args(arguments)

    # Parses utt2spk files into an utterance to speaker mapping
    with args.speakers_file as speaker_file:
        speakers = {}
        for line in speaker_file:
            utterance_id, speaker = line.split()
            speakers[utterance_id] = f"{speaker}_{utterance_id}" #speaker # f"{speaker}_{utterance_id}"

    # Writes a new file for every input file ending in *.speakers containing a speaker ID in each line
    # corresponding to the utterance IDs in the first column of the input files
    for path in args.text_files:
        with open(path, "r", encoding="utf-8") as file, open(path + ".speakers", "w", encoding="utf-8") as out:
            for line in file:
                out.write(speakers[line.split(maxsplit=1)[0]] + "\n")


if __name__ == '__main__':
    import sys

    main(sys.argv[1:])
