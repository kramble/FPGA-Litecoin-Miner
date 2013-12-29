#!/bin/bash
# QROOT is the root directory of your quartus install
# Mine is ~/altera/13.1/quartus/ but yours may be different
QROOT=~/altera/13.1/quartus  # change to your directory
$QROOT/bin/quartus_stp -t mine.tcl
