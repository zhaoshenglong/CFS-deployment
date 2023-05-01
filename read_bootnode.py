#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import sys

import toml


def main():
    with open('bootnode.toml', 'r') as f:
        mcid = toml.load(f)
    key = sys.argv[1]
    print(mcid[key])


if __name__ == '__main__':
    main()
