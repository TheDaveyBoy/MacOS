#!/bin/bash

##########################################################################################################
### Create an Encrypted String ###########################################################################
### this will be needed to pass credentials securely https://github.com/brysontyrrell/EncryptedStrings ###
##########################################################################################################

#####################################################################################
### JSS Paramaters ##################################################################
### $4 = Username Encrypted String ##################################################
### $5 = Password Encrypted String ##################################################
### $6 = Amount of attempts to run Re-Key Process. 2 is the default is left blank ###
#####################################################################################

#################################
### String Encrypted Username ###
#################################
SALTUN=""
KUN=""
UN=$(echo "$4" | /usr/bin/openssl enc -aes256 -md md5 -d -a -A -S "$SALTUN" -k "$KUN")

#################################
### String Encrypted Password ###
#################################
SALTPW=""
KPW=""
PW=$(echo "$5" | /usr/bin/openssl enc -aes256 -md md5 -d -a -A -S "$SALTPW" -k "$KPW")

###########################
### Get UUID of FV User ###
###########################
userNameUUID=$(dscl . -read /Users/$UN/ GeneratedUID | awk '{print $2}')
userCheck=`fdesetup list | awk -v usrN="$userNameUUID" -F, 'match($0, usrN) {print $1}'`

################################################
### Get OS Build. This checks for FV version ###
################################################
BUILD=`/usr/bin/sw_vers -buildVersion | awk {'print substr ($0,0,2)'}`

##########################################
### Check to see if user is FV enabled ###
##########################################
if [ "${userCheck}" != "$UN" ]; then
	echo "This user is not a FileVault 2 enabled user."
	exit 3
fi

############################################################################
### Re-run the process. ####################################################
### Store amount of tries in JSS, if left blank then the default is two. ###
############################################################################
try=0
if [ ! -z "$6" ]
then
	maxTry=$6
else
	maxTry=2
fi

##########################################################
### Check to see if the encryption process is complete ###
##########################################################
encryptCheck=`fdesetup status`
statusCheck=$(echo "${encryptCheck}" | grep "FileVault is On.")
expectedStatus="FileVault is On."

##########################################################
### Check to see if the encryption process is complete ###
##########################################################
if [ "${statusCheck}" != "${expectedStatus}" ]; then
	echo "The encryption process has not completed."
	echo "${encryptCheck}"
	exit 4
fi

########################################################################
### ReKey FileVault, this will take in account what OS is being used ###
########################################################################
try=$((try+1))
if [[ $BUILD -ge 13 ]] &&  [[ $BUILD -lt 17 ]]; then
	## This "expect" block will populate answers for the fdesetup prompts that normally occur while hiding them from output
	result=$(expect -c "
	log_user 0
	spawn fdesetup changerecovery -personal
	expect \"Enter a password for '/', or the recovery key:\"
	send {"$PW"}   
	send \r
	log_user 1
	expect eof
	" >> /dev/null)
	elif [[ $BUILD -ge 17 ]]; then
		result=$(expect -c "
		log_user 0
		spawn fdesetup changerecovery -personal
		expect \"Enter the user name:\"
		send {"$UN"}   
		send \r
		expect \"Enter a password for '/', or the recovery key:\"
		send {"$PW"}   
		send \r
		log_user 1
		expect eof
	")
else
	echo "OS version not 10.9+ or OS version unrecognized"
	echo "$(/usr/bin/sw_vers -productVersion)"
	exit 5
fi

###################################################################################
### Write some logs to Jamf, so other administrators can easily see the outcome ###
###################################################################################
while true
do
	if [[ $result = *"Error"* ]]
	then
		echo "Error Changing Key"
		if [ $try -ge $maxTry ]
		then
			echo "Quitting... Too Many failures"
			exit 0
		else
			echo $result
		fi
	else
		echo "Successfully Changed FV2 Key"
		exit 0
	fi
done