#! /bin/bash
(/usr/lib/YaST2/bin/y2base -l /dev/fd/2 $1 $2 testsuite >$3) 2>&1 | fgrep -v " <0> " | grep -v "^$" | sed 's/^....-..-.. ..:..:.. [^)]*) //g' > $4
