
Patch Check
====================

See: https://www.pythian.com/blog/linux-patching-and-oracle-how-to-detect-rpm-conflicts-before-they-happen-2/

pc.pl is used to compare a list of linux RPM packages with dependencies that Oracle has on those RPMs.

This is useful to help judge the impact that updating packages will have on Oracle.

## RPM List
The list of RPM files should be in a text file

The list of patches should not include the .rpm suffix on the filename if it does, remove it

eg.
popt-1.10.2.3-22.el5_6.2.i386
kernel-headers-2.6.18-238.27.1.el5.x86_64
kernel-devel-2.6.18-238.27.1.el5.x86_64
rhn-client-tools-0.4.20-46.el5.noarch
libgcc-4.1.2-50.el5.x86_64
libgcc-4.1.2-50.el5.x86_64
...

## Oracle home list

The list of oracle homes to check could also be in a file

eg.

/u01/app/oracle/product/11.2.0/grid
/u01/app/oracle/product/11.2.0/vmdb01

use the oracle home list from a shell script - see pc.sh

If the oracle homes are not all owned by the same account, you will 
probably need to run pc.pl as root.

## run the command

Here's an example usage

  pc.pl -oracle_home $ORACLE_HOME -linux_patch_list linux_patches.txt




