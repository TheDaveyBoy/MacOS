#!/bin/bash

########################################################################################
### Need to enure that Yubico-Piv-Tool is installed before running this script. ########
### This will change the old pin to the new pin without the old pin being needed. ######
### Also check to see if there is a capital letter, lowercase letter, and a number. ####
########################################################################################

###############################################
### GLOBAL PUK is $4. Store this into JAMF. ###
###############################################

##############################################################################
### Prompt the user to insert card, once inserted prompt will go away. #######
### This will only run if there is a certificate on the SmartCard/YubiKey. ###
##############################################################################
"/Library/Application Support/JAMF/bin/jamfHelper.app/Contents/MacOS/jamfHelper" \
-windowType utility -title "SmartCard/YubiKey Not Detected!" -description "Please insert your SmartCard/YubiKey." \
-alignDescription left -lockHUD & while [[ $( security list-smartcards 2>/dev/null \
| grep -c com.apple.pivtoken ) -lt 1 ]]; do sleep 1; done; kill -9 $!

###############################################
### Activate Finder Window for User Input. ####
###############################################
osascript -e 'tell application "Finder"
	if not running then
    		run
    		delay 0.25
	end if
	activate
end tell'

############################################################################
### Loop forever until the user gives a correct requirements or cancels. ###
############################################################################
x=0
while [ "$x" -le 0 ]
do

	#################################################################################
	### This will prompt the user for their new pin and store it into a variable. ###
	#################################################################################
	userPinNew=$(osascript -e '
	tell application "Finder"
	   display dialog "Please enter a new pin.\n\nThe pin must contain:\n-A capital letter\n-A lowercase letter\n-A number\n\nAdditionally:\n-The pin MUST be exactly 8 characters\n-The pin CANNOT contain a special character" default answer "" with title "New Pin" buttons {"Stop","OK"} default button "OK" with hidden answer
	   if button returned of result is "OK" then
	      	set userPinNew to the (text returned of the result)
	   else
	      	set userPinNew to "Stop"
	   end if
	end tell')
    
    	##################################################
	### Stop the script if Stop button is pressed. ###
	##################################################
	if [ $userPinNew == "Stop" ]; then
		exit 0
	fi

	#################################################
	### Check to see if new pin is 8 digits long. ###
	#################################################
	eightDigitCheck="$userPinNew"
	eightDigitCheckSize=${#eightDigitCheck}

	##############################################################################################
	### Check to see if the new pin contains a Capital Letter, Lowercase Letter, and a number. ###
	##############################################################################################
	if [ $eightDigitCheckSize -eq 8 ]
	then
		if [[ $userPinNew =~ [A-Z] ]]
		then
			if [[ $userPinNew =~ [a-z] ]]
			then
				if [[ $userPinNew =~ [0-9] ]]
				then
					if [[ $userPinNew =~ [[:punct:]] ]]
					then
						title='SmartCard/YubiKey Pin Not Changed!'
						osascript -e "display dialog \"The new pin you provided contains a special character!\n\nThe pin must contain:\n-A capital letter\n-A lowercase letter\n-A number\n\nAdditionally:\n-The pin MUST be exactly 8 characters\n-The pin CANNOT contain a special character\" buttons {\"OK\"} default button \"OK\" with title \"$title\""
					else					
						##########################################
						### Unlock PUK and set to factory pin. ###
						##########################################
						yubico-piv-tool -aunblock-pin -P$4 -N$userPinNew
                    	
						####################
						### Escape loop. ###
						####################
	                    x=$(( $x + 1 ))

						title='SmartCard/YubiKey Pin Changed & Unlocked!'
						osascript -e "display dialog \"The SmartCard/YubiKey pin has been successfully changed & unlocked!\" buttons {\"OK\"} default button \"OK\" with title \"$title\""
					fi
				else
					title='SmartCard/YubiKey Pin Not Changed!'
					osascript -e "display dialog \"The new pin you provided did not contain a number!\n\nThe pin must contain:\n-A capital letter\n-A lowercase letter\n-A number\n\nAdditionally:\n-The pin MUST be exactly 8 characters\n-The pin CANNOT contain a special character\" buttons {\"OK\"} default button \"OK\" with title \"$title\""
				fi
			else
				title='SmartCard/YubiKey Pin Not Changed!'
				osascript -e "display dialog \"The new pin you provided did not contain a lowercase letter!\n\nThe pin must contain:\n-A capital letter\n-A lowercase letter\n-A number\n\nAdditionally:\n-The pin MUST be exactly 8 characters\n-The pin CANNOT contain a special character\" buttons {\"OK\"} default button \"OK\" with title \"$title\""
			fi
		else
			title='SmartCard/YubiKey Pin Not Changed!'
			osascript -e "display dialog \"The new pin you provided did not contain a capital letter!\n\nThe pin must contain:\n-A capital letter\n-A lowercase letter\n-A number\n\nAdditionally:\n-The pin MUST be exactly 8 characters\n-The pin CANNOT contain a special character\" buttons {\"OK\"} default button \"OK\" with title \"$title\""
		fi
	else
		title='SmartCard/YubiKey Pin Not Changed!'
		osascript -e "display dialog \"The new pin you provided was not 8 characters long!\n\nThe pin must contain:\n-A capital letter\n-A lowercase letter\n-A number\n\nAdditionally:\n-The pin MUST be exactly 8 characters\n-The pin CANNOT contain a special character\" buttons {\"OK\"} default button \"OK\" with title \"$title\""
	fi
done
