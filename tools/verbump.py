#!/usr/bin/env python
# Automakes a release preparation for a post-release project
# * Create a git tag
# * Bump version in configure.ac and commit it

import re
import os
import sys
import subprocess

micro_version_re = re.compile('m4_define.*gi_micro_version, ([0-9]+)')
micro_version_replace = 'm4_define(gi_micro_version, %d)\n'

def _extract_config_log_variable(name):
    f = open('config.log')
    keystart = name + '=\''
    for line in f:
        if line.startswith(keystart):
            return line[len(keystart):-2]
    f.close()
    fatal("Failed to find '%s' in config.status" % (name, ))

if not os.path.isfile('config.log'):
    fatal("Couldn't find config.log; did you run configure?")
package = _extract_config_log_variable('PACKAGE_TARNAME')
version = _extract_config_log_variable('VERSION')

f = open('configure.ac');
newf = open('configure.ac.new', 'w')
for line in f:
  m = micro_version_re.match(line)
  if not m:
    newf.write(line)
    continue
  v = int(m.group(1))
  newv = v+1
  print "Will update micro version from %s to %s" % (v, newv)
  newf.write(micro_version_replace % (newv, ))
newf.close()

os.rename('configure.ac.new', 'configure.ac')
print "Successfully wrote new 'configure.ac' with post-release version bump"

args=['git', 'commit', '-m', "configure: Post-release version bump", 'configure.ac']
print "Running: %r" % (args, )
subprocess.check_call(args)
