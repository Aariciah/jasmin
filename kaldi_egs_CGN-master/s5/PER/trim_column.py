#!/usr/bin/env python
import sys


def main():
    # Removes the utterance IDs stored in the first column from the input
    for line in sys.stdin:
        columns = line.strip().split(' ', 1)
        print(columns[1] if len(columns) > 1 else '')


if __name__ == '__main__':
    main()
