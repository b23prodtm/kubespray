#!/usr/bin/python
import sys
if int(sys.version.partition('.')[0]) < 3:
    print("This script needs python 3 or later. Try python3.")
    exit(1)
from ruamel.yaml import YAML
import datetime
from pathlib import Path

def main (argv):
    if len (argv) < 3:
        print("Usage: %s <path/to/thevars.yml> <var_name> <value>..." % argv[0])
    t = datetime.datetime.now()
    ifile = Path(argv[1])
    ofile = Path('%s.%s' % (argv[1], t.strftime('%H-%M-%S-%Y-%m-%d')))
    y = YAML()
    vars = y.load(ifile)
    y.dump(vars, ofile)
    for k in range(2, len(argv) - 1, 2):
        print("Set %s: %s" % (argv[k], argv[k+1]))
        try:
            vars[argv[k]] = argv[k+1]
        except TypeError:
            print("Value not found for %s" % argv[k])
    y.dump(vars, ifile)

if __name__ == '__main__':
    main(sys.argv)
