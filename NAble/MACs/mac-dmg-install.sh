#!/bin/bash
curl -O https://github.com/CW-Khristos/MSP_MACS/raw/master/MacAgentInstallation.dmg
SRC=MacAgentInstallation.dmg
while getopts 'k:c:i:s:p:a:x:r:P:T:D:V:' OPTION
do
	case $OPTION in
	k)	ACTIVATE_KEY=$OPTARG
		;;
	c)	CNAME=$OPTARG
		;;
	i)	CID=$OPTARG
		;;
	s)	SERVER=$OPTARG
		;;
	p)	PROTOCOL=$OPTARG
		;;
	a)	PORT=$OPTARG
		;;
	x)	PROXY=$OPTARG
		;;
	T)	SRC=$OPTARG
		;;
	esac
done
if [ ! -f "${SRC}" ] ; then
	echo "Disk image ${SRC} does not exists"
	exit 1
fi
#Default Values for port and protocol
if [ -z $PORT ] ; then 
	PORT=443
fi
if [ -z $PROTOCOL ] ; then 
	PROTOCOL=https
fi

usage() {
	cat <<-EOF
	
	EOF
}

decrypt_key() {
	
	DecryptedKey=$(echo $1 | openssl enc -base64 -d -A)
	#echo $DecryptedKey

	#### decrypted key format:  https://warsteiner.lab2.n-able.com:443|37683|1|0
	uri=$( echo -n $DecryptedKey | awk -F"|" '{print $1}' )
	APPLIANCE=$( echo -n $DecryptedKey | awk -F"|" '{print $2}')
	ApplianceType=$( echo -n $DecryptedKey | awk -F"|" '{print $3}' )
	PROTOCOL=$( echo -n $uri | awk -F":" '{print $1}')
	SERVER=$( echo -n $uri | awk -F":" '{print $2}' | sed -e 's!^//!!' )
	PORT=$( echo -n $uri | awk -F":" '{print $3}' )
}

if [ -z "${SERVER}" ] || [ -z "${CNAME}" ]  || [ -z "${CID}" ] ; then
	if [ ! -z "$ACTIVATE_KEY" ] ; then	
		decrypt_key $ACTIVATE_KEY
	else
		usage
		exit 1
	fi
fi

hdiutil mount $SRC
if [ ! -d /Applications/Mac_Agent.app ]; then
	mkdir /Applications/Mac_Agent.app
fi
cp -fR "/Volumes/Mac Agent Installation/.Mac_Agent.app/Contents" /Applications/Mac_Agent.app/
hdiutil unmount "/Volumes/Mac Agent Installation"
chown -R root /Applications/Mac_Agent.app/
chgrp -R wheel /Applications/Mac_Agent.app/
validate_path=/Applications/Mac_Agent.app/Contents/Daemon/usr/sbin/InitialValidate
if [ ! -z $SERVER ] && [ ! -z $PORT ] && [ ! -z $PROTOCOL ] ; then
	validate_command="sudo \"${validate_path}\" -s $SERVER -n $PORT -p $PROTOCOL "
else
	echo "Not valid activation key"
fi
if [ ! -z $PROXY ] ; then
	validate_command=${validate_command}"-x $PROXY "
fi
if [ ! -z $CID ] && [ ! -z "$CNAME" ] ; then
	validate_command=${validate_command}" -f /tmp/nagent.conf -i $CID -c \"$CNAME\" -l /tmp/nagent_install_log"
elif  [ ! -z $APPLIANCE ] ; then
	validate_command=${validate_command}" -f /tmp/nagent.conf -a $APPLIANCE -l /tmp/nagent_install_log"
else
	usage
	exit 1
fi
echo $validate_command
# Cleanup 
`rm -f /tmp/nagent.conf`
validate_rc=0
# Run validate command and install upon success
eval "$validate_command"
validate_rc=$?
# On failure display error message
if [ $validate_rc -gt 0 ] ; then
	echo "Could not successfully self-register agent"
	case $validate_rc in 
		10)
			echo "Could not connect to N-central server";
			;;
		11)
			echo "Invalid Customer Name";
			;;
		12)
			echo "Invalid Customer ID";
			;;
		13)	
			echo "Invalid Appliance ID";
			;;
		14)
			echo "Local Asset Discovery failed, check /tmp/nagent_install_log for more details";
			;;
		15)
			echo "The N-central server cannot register the agent";
			;;
		16)
			echo "Unable to create Configuration file";
			;;
		17)
			echo "Unable to create log file";
			;;
		*)
			usage;
			echo "Unknown Error occured, check /tmp/nagent_install_log for more details";
			;;
	esac
	/Applications/Mac_Agent.app/Contents/Daemon/usr/sbin/uninstall-nagent y
	exit 1
fi
echo "Update nagent.conf"
cat <<EOF >> /tmp/nagent.conf
    logfilename=/var/log/N-able/N-agent/nagent.log
    loglevel=3
    homedir=/Applications/Mac_Agent.app/Contents/Daemon/home/nagent/
    thread_limitation=50 
    poll_delay=1
    datablock_size=20
EOF
cp -f /tmp/nagent.conf /Applications/Mac_Agent.app/Contents/Daemon/etc/
rm -f /tmp/nagent.conf
cp -f /Applications/Mac_Agent.app/Contents/Daemon/etc/*.plist /Library/LaunchDaemons/
launchctl load /Library/LaunchDaemons/com.n-able.agent-macosx.plist
launchctl load /Library/LaunchDaemons/com.n-able.agent-macosx.logrotate-daily.plist
echo "The install was successful."

