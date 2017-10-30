#!/usr/bin/env python

import sys
# As of python 2.7, optparse is deprecated
import argparse

def main():
    ''' main function '''
	parser = argparse.ArgumentParser()
	parser.add_argument("--id", default=sys.argv[0], help="id")

	args = parser.parse_args()

    
if __name__ == '__main__':
    main()
