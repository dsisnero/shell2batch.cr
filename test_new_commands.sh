#!/bin/bash

# Test new bash commands
cat file.txt
head -n 10 file.txt
tail -n 5 file.txt
wc -l file.txt
sort file.txt
uniq file.txt
diff file1.txt file2.txt
find . -name "*.txt"
chmod +x script.sh
which python
date
time
whoami
hostname
env | head -n 5
alias ll='ls -l'
history | tail -n 3
kill -9 1234
ps aux | grep python
sleep 5
source config.sh
md5sum file.txt
sha1sum file.txt
sha256sum file.txt