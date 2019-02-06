#!/bin/bash
printf "\033c" # Clear screen

# Check Android SDK
if [ $ANDROID_HOME == "" ]; then
  pause "Please set $ANDROID_HOME environment variable."
  exit
fi

# Get path variables
ROOTPATH=`pwd`
AWK=awk
FASTBOOT=$ANDROID_HOME/platform-tools/fastboot
UNLOCK_CODE=

### Support function

function getkeys {
  read keyinput
  echo $keyinput
}

function clearkeys {
  while read -r -t 0; do read -r; done
}

function pause {
  if [ "$1" != "" ]; then
    echo $1
  fi
  clearkeys
  echo -e "Press ENTER to continue..."
  read
}


function check_fastboot {
  if [ "`$FASTBOOT devices 2>&1 | grep fastboot`" != "" ]; then
    clearkeys
    echo 1
  else
    echo 0
  fi
}

function wait_fastboot {
  while [ $(check_fastboot) -eq 0 ]
  do
    sleep 1
  done
}

#######################################################

### Check rootpath
if [ "`echo $ROOTPATH | grep ' '`" != "" ]; then
  pause "This script does not support a directory with space."
  exit
fi

if [ ${#ROOTPATH} -gt 200 ]; then
  pause "The path is too long, extract the script package on a shorter path."
  exit
fi

echo 

echo 
pause "Hold down the volume button minus and connect the USB cable to boot into the fastboot mode."
echo

echo "Waiting connection in FASTBOOT..."
wait_fastboot
echo

echo -en "Enter unlock code: "
UNLOCK_CODE=$(getkeys)
echo -e "Use the volume buttons to select YES and press the power button."
$FASTBOOT oem relock $UNLOCK_CODE
echo
pause 