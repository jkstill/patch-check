#!/bin/sh

cd ..

mkdir -p $HOME/tmp

DISTFILE=$HOME/tmp/patch-check_dist.zip

zip -r $DISTFILE \
 patch-check/pc.pl \
 patch-check/pc.sh \
 patch-check/patch_list.txt \
 patch-check/verbose.pm \
 patch-check/README \
 patch-check/oracle_homes.txt

echo Patch Check distribution is $DISTFILE

