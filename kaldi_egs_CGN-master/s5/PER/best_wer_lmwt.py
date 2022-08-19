#!/usr/bin/env python
import argparse
from argparse import ArgumentParser, FileType
from os import path


def main(arguments):
    parser = ArgumentParser()
    parser.add_argument(
        "base_directory",
        help="Directory containing wer files"
    )
    parser.add_argument(
        "min_lmwt",
        type=int,
        help="Minimum LMWT used during decoding"
    )
    parser.add_argument(
        "max_lmwt",
        type=int,
        help="Maximum LMWT used during decoding"
    )
    parser.add_argument(
        "-p",
        "--print-error-rates",
        action="store_true",
        help="Optionally prints word and sentence error rates for the best LMWT"
    )
    args = parser.parse_args(arguments)

    wers = []
    for lmwt in range(args.min_lmwt, args.max_lmwt + 1):
        with open(path.join(args.base_directory, f"wer_{lmwt}")) as wer_file:
            lines = wer_file.readlines()
            wers.append((float(lines[1].split()[1]), float(lines[2].split()[1]), lmwt))

    wer, ser, lmwt = sorted(wers, key=lambda entries: entries[:2])[0]
    if args.print_error_rates:
        print(wer, ser, lmwt)
    else:
        print(lmwt)


if __name__ == '__main__':
    import sys

    main(sys.argv[1:])
