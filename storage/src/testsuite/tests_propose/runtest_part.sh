#! /bin/bash
#echo XXXXXXXXXXXXXXXXXXXXXXXXXX $1 $2 $3 
(/usr/lib/YaST2/bin/y2base -l /dev/fd/1 $1 testsuite 2>&1 ) | grep "OUT:" | grep -v "^$" | sed 's/^....-..-.. ..:..:.. [^)]*).*OUT:/  /g' >"$2" 2>"$3"
