#!/bin/bash

########################################################################################################
### This script was refactored and augmented to create an automated process without user interaction ###
### An admin account with a secureToken will be utilized ###############################################
########################################################################################################

##########################################################################################################
### Create an Encrypted String ###########################################################################
### this will be needed to pass credentials securely https://github.com/brysontyrrell/EncryptedStrings ###
### The Copyright below is to stay in terms of fair use ##################################################
##########################################################################################################

################################################################################
### The MIT License (MIT)
###
### Copyright (c) 2015 Bryson Tyrrell
###
### Permission is hereby granted, free of charge, to any person obtaining a copy
### of this software and associated documentation files (the "Software"), to deal
### in the Software without restriction, including without limitation the rights
### to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
### copies of the Software, and to permit persons to whom the Software is
###furnished to do so, subject to the following conditions:
###
### The above copyright notice and this permission notice shall be included in
### all copies or substantial portions of the Software.
### 
### THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
### IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
### FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
### AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
### LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
### OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
### THE SOFTWARE.
#################################################################################

############################################################################
### Jamf FileVault ReKey Prompt User #######################################
### https://github.com/jamf/FileVault2_Scripts/blob/master/reissueKey.sh ###
### The Copyright below is to stay in terms of fair use ####################
############################################################################

########################################################################################
### Copyright (c) 2017, JAMF Software, LLC.  All rights reserved.
###
###       Redistribution and use in source and binary forms, with or without
###       modification, are permitted provided that the following conditions are met:
###               * Redistributions of source code must retain the above copyright
###                 notice, this list of conditions and the following disclaimer.
###               * Redistributions in binary form must reproduce the above copyright
###                 notice, this list of conditions and the following disclaimer in the
###                 documentation and/or other materials provided with the distribution.
###               * Neither the name of the JAMF Software, LLC nor the
###                 names of its contributors may be used to endorse or promote products
###                 derived from this software without specific prior written permission.
###
###       THIS SOFTWARE IS PROVIDED BY JAMF SOFTWARE, LLC "AS IS" AND ANY
###       EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
###       WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
###       DISCLAIMED. IN NO EVENT SHALL JAMF SOFTWARE, LLC BE LIABLE FOR ANY
###       DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
###       (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
###       LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
###       ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
###       (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
###       SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
########################################################################################

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
