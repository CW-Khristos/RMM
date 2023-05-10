#!/bin/bash

function postError {
	echo "  This could indicate a connection issue, a security issue or a problem with the vendor."
	echo "  Please report this error."
	echo "- Installation cannot proceed; exiting..."
	exit 1
}

function downloadVerify {
	echo "- Downloading installer (as $2) from URL:"
	echo "  $1"
	#-- download the file
	curl -L $1 -o $2
	#-- verify the PKG
	spctl -a -t open --context context:primary-signature -v $2
	varVerification=$?
	if [[ $varVerification != 0 ]]; then
		echo "- ERROR: $2 could not be verified."
		postError
	fi
	#-- verify the APP
	EPOCHTIME=$(date +%s)
	varMountPoint=/Volumes/$EPOCHTIME
	hdiutil attach $2 -mountpoint $varMountPoint -quiet -nobrowse -noverify -noautoopen
	varAPPFile=$(ls -d $varMountPoint/*.app)
	codesign -dv "$varAPPFile" 2>&1 | grep -qF "$3"
	varVerification=$?
	if [[ $varVerification != 0 ]]; then
		echo "- ERROR: APP folder failed signature check."
		postError
	fi
	echo "- PKG file successfully verified."
}

$space = ' '
$replace = '%20'
$varSite = "$env:strSite"
$varCompany = "$env:strCompany"
$strLineSeparator = "-------------------"
$CWKeyThumbprint = "$env:ConnectWiseControlPublicKeyThumbprint"
$CWControlInstallURL = "$env:ConnectWiseControlInstallerMACUrl"

if [ -z "$CWKeyThumbprint" ]; then
  echo "CWKeyThumbprint not defined"
  exit -1
fi

if [ -z "$CWControlInstallURL" ]; then
  echo "CWControlInstallURL not defined"
  exit -1
fi

if [ -z "$varCompany" ]; then
  echo "varCompany not defined"
  $varCompany = "$env:CS_PROFILE_NAME"
fi
$varCompany=$(echo "$varCompany" | sed "s/$space/$replace/g")
$CWControlInstallURL = "$CWControlInstallURL&y=Guest&c=$varCompany"

if [ -z "$varSite" ]; then
  echo "varSite not defined"
  $CWControlInstallURL = "$CWControlInstallURL&c=&c=&c=&c=&c=&c=&c="
else
  $varSite=$(echo "$varSite" | sed "s/$space/$replace/g")
  $CWControlInstallURL = "$CWControlInstallURL&c=$varSite&c=&c=&c=&c=&c=&c="
fi

echo "==================================="
echo "SC Site : $varSite"
echo "SC Company : $varCompany"
echo "SC Thumbprint : $CWKeyThumbprint"
echo "SC Install URL : $CWControlInstallURL"
echo "SC Base URL : $env:ConnectWiseControlBaseUrl"
echo "==================================="

#run global installer
downloadVerify "$CWControlInstallURL" "CWControl.pkg" "4c2272fba7a7380f55e2a424e9e624aee1c14579" "CW Control Installer"
"$varMountPoint/CWControl.pkg" > /dev/null
sleep 10
hdiutil detach $varMountPoint
echo "- CW Control Installer has been run. Exiting."