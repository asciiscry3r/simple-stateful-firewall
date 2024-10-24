# -*- coding: utf-8 -*-

import os
import shlex
import shutil
import sys
import datetime
import subprocess


os.setuid(os.geteuid())

d = {}
with open("/etc/sysctl.d/sysctldump.conf") as f:
    for line in f:
       (key, val) = line.split("=")
       d[str(key)] = val

for item in d:
   print(d[item])
   subprocess.call(["sudo", "sysctl", "-n", item])

with open('/proc/sys/net/ipv4/conf/default/ignore_routes_with_linkdown') as f:
    max_map_count = int(f.read())
    print(max_map_count)
