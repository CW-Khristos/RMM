#! /bin/bash
UID=$1
INSTALL="/Applications/bm#$UID#.pkg"
curl -O $INSTALL https://raw.githubusercontent.com/CW-Khristos/MSP_MACS/master/mxb-macosx-x86_64.pkg
installer -dumplog -pkg $INSTALL -target /Applications
rm -f $INSTALL