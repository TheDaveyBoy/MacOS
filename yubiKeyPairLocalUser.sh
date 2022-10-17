#!/bin/bash

################################################################################################
### Need to enure that Yubico-Piv-Tool is installed before running this script. ################
### This will change the old 123456 pin to the new pin. ########################################
### Also check to see if there is a capital letter, lowercase letter, and a number. ############
################################################################################################

##########################################################
### Variables you need to store in the script in JAMF. ###
##########################################################

#############################################
### Global Management Key Variable is $4. ###
#############################################

#########################
### Global PUK is $5. ###
#########################

###############################################################################################
### Prompt the user to insert SmartCard/YubiKey, once inserted the prompt will go away. #######
### This will only run if there is a certificate on the SmartCard/YubiKey. ####################
###############################################################################################
"/Library/Application Support/JAMF/bin/jamfHelper.app/Contents/MacOS/jamfHelper" \
-windowType utility -title "SmartCard/YubiKey Not Detected!" -description "Please insert your SmartCard/YubiKey." \
-alignDescription left -lockHUD & while [[ $( security list-smartcards 2>/dev/null \
| grep -c com.apple.pivtoken ) -lt 1 ]]; do sleep 1; done; kill -9 $!

###########################################
### Change SmartCard PIN Attempts to 5. ###
###########################################
yubico-piv-tool -a verify -P 123456 -a pin-retries --pin-retries=5 --puk-retries=5

####################################################
### Change Default Key to Global Management Key. ###
####################################################
yubico-piv-tool -a set-mgm-key -n $4

#########################################
### Change Default PUK to Global PUK. ###
#########################################
yubico-piv-tool -a change-puk -P 12345678 -N $5
yubico-piv-tool -a change-puk -P $5 -N $5

#########################################################################################
### Grab the hash and store it into a variable to pass into the sc_auth pair command. ###
#########################################################################################
yubiKeyHash=$(sc_auth identities | head -n 3 | awk '{print $1;}' | sort | head -1)

############################################
### Get the name for the logged in user. ###
############################################
userName=$(/usr/bin/python -c 'from SystemConfiguration import SCDynamicStoreCopyConsoleUser; import sys; username = (SCDynamicStoreCopyConsoleUser(None, None, None) or [None])[0]; username = [username,""][username in [u"loginwindow", None, u""]]; sys.stdout.write(username + "\n");')

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

x=0
while [ "$x" -le 0 ]
do
	#################################################################################
	### This will prompt the user for their new pin and store it into a variable. ###
	#################################################################################
	userPinNew=$(osascript -e '
	tell application "Finder"
	   display dialog "Please set a pin.\n\nThe pin must contain:\n-A capital letter\n-A lowercase letter\n-A number\n\nAdditionally:\n-The pin MUST be exactly 8 characters\n-The pin CANNOT contain a special character" default answer "" with title "New Pin" buttons {"Stop","OK"} default button "OK" with hidden answer
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
						title='SmartCard/YubiKey Pin Not Set!'
						osascript -e "display dialog \"The new pin you provided contains a special character!\n\nThe pin must contain:\n-A capital letter\n-A lowercase letter\n-A number\n\nAdditionally:\n-The pin MUST be exactly 8 characters\n-The pin CANNOT contain a special character\" buttons {\"OK\"} default button \"OK\" with title \"$title\""
					else					
	                    			##########################################
						### Unlock PUK and change factory pin. ###
						##########################################
						yubico-piv-tool -achange-pin -P123456 -N$userPinNew
                    
	                    title='Pin & Textron/MyEric Password Required!'
						osascript -e "display dialog \"The next two dialogs will ask you for your PIN & your Textron/MyEric Password.\n\nIf the two dialogs do NOT appear, then this SmartCard/YubiKey has already been paired to your profile.\n\nPlease press OK to continue.\" buttons {\"OK\"} default button \"OK\" with title \"$title\""
                    
	                    			###################################
						### Pair SmartCard/YubiKey pin. ###
						###################################
						output=$(sc_auth pair -v -u $userName -h $yubiKeyHash | awk '{print $8 $9 $10 $11}')
					
						if [[ $output == *"SmartCardisalreadypaired."* ]]; then
	                        			###################################################################
							### Inform user that the SmartCard / YubiKey is already paired. ###
							###################################################################
							title='SmartCard/YubiKey Already Paired!'
							osascript -e "display dialog \"This SmartCard/YubiKey is already paired to your profile!\" buttons {\"OK\"} default button \"OK\" with title \"$title\""
                        
	                        x=$(( $x + 1 ))
						else
							##############################
							### Pair user to the hash. ###
							##############################
							title='SmartCard/YubiKey Successfully Paired!'
							osascript -e "display dialog \"This SmartCard/YubiKey has been successfully paired to your profile!\" buttons {\"OK\"} default button \"OK\" with title \"$title\""
                        	
                            ##################
                            ### Exit Loop. ###
                            ##################
	                        x=$(( $x + 1 ))
						fi
					fi
				else
					title='SmartCard/YubiKey Pin Not Set!'
					osascript -e "display dialog \"The new pin you provided did not contain a number!\n\nThe pin must contain:\n-A capital letter\n-A lowercase letter\n-A number\n\nAdditionally:\n-The pin MUST be exactly 8 characters\n-The pin CANNOT contain a special character\" buttons {\"OK\"} default button \"OK\" with title \"$title\""
				fi
			else
				title='SmartCard/YubiKey Pin Not Set!'
				osascript -e "display dialog \"The new pin you provided did not contain a lowercase letter!\n\nThe pin must contain:\n-A capital letter\n-A lowercase letter\n-A number\n\nAdditionally:\n-The pin MUST be exactly 8 characters\n-The pin CANNOT contain a special character\" buttons {\"OK\"} default button \"OK\" with title \"$title\""
			fi
		else
			title='SmartCard/YubiKey Pin Not Set!'
			osascript -e "display dialog \"The new pin you provided did not contain a capital letter!\n\nThe pin must contain:\n-A capital letter\n-A lowercase letter\n-A number\n\nAdditionally:\n-The pin MUST be exactly 8 characters\n-The pin CANNOT contain a special character\" buttons {\"OK\"} default button \"OK\" with title \"$title\""
		fi
	else
		title='SmartCard/YubiKey Pin Not Set!'
		osascript -e "display dialog \"The new pin you provided was not 8 characters long!\n\nThe pin must contain:\n-A capital letter\n-A lowercase letter\n-A number\n\nAdditionally:\n-The pin MUST be exactly 8 characters\n-The pin CANNOT contain a special character\" buttons {\"OK\"} default button \"OK\" with title \"$title\""
	fi
done
