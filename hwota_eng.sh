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
OEMPATH=$ROOTPATH/oeminfo
RECPATH=$ROOTPATH/recovery
FASTBOOT=$ANDROID_HOME/platform-tools/fastboot
ADB=$ANDROID_HOME/platform-tools/adb
UNLOCK_CODE=

##########################################################################################

function check_fastboot {
  if [ "`$FASTBOOT devices 2>&1 | grep fastboot`" != "" ]; then
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

function check_lock {
  if [ "`$FASTBOOT oem lock-state info 2>&1 | grep USER | grep UNLOCKED`" != "" ]; then
   echo 0
  else
   echo 1
  fi
}

function check_adb {
  if [ "`$ADB devices 2>&1 | grep recovery`" != "" ]; then
    echo 1
  else
    echo 0
  fi
}

function wait_adb {
  $ADB kill-server > /dev/null 2>&1
  while [ $(check_adb) -eq 0 ]
  do
    $ADB kill-server > /dev/null 2>&1
    sleep 1
  done
}

function pause {
  if [ "$1" != "" ]; then
    echo $1
  fi
  echo -e "Press ENTER to continue..."
  read
}

function unlock_device {
  if [ $(check_lock) -eq 1 ]; then
    echo -e "Before the next step, you need to unlock the loader."
    if [ "$UNLOCK_CODE" = "" ]; then
      echo -en "Enter unlock code:"
      UNLOCK_CODE=$(getkeys)
    else
      echo "Use unlock code $UNLOCK_CODE"
    fi
    echo
    echo -e "Use the volume buttons to select YES and press the power button."
    $FASTBOOT oem unlock $UNLOCK_CODE
    if [ "$1" != "" ]; then
      echo
      pause "$1"
    fi
  fi
}

function getkeys {
  read keyinput
  echo $keyinput
}

function isnum {
  if [ $(echo "$1" | grep -c '^[0-9]\+$') = 1 ]; then
    echo 1
  else
    echo 0
  fi
}

function format_str {
  strlen=${#1}
  count=$2
  remain=$(( count - strlen ))
  echo -n "$1"
  printf '%*s' "$remain"
}

function list_config {
  echo
  echo -e "****************************************"
  echo -e "* $(format_str 'Model:  '$MODEL 37)*"
  echo -e "* $(format_str 'Build:  '$BUILD 37)*"
if [ "$UPDATE_TYPE" = "1" ]; then
  echo -e "* Source: SDCard HWOTA directory       *"
else
  echo -e "* Source: Script update directory      *"
fi
if [ "$UPDATE_TYPE" = "1" ]; then
  echo -e "* Update: Same brand update            *"
else
  echo -e "* $(format_str 'Update: Rebrand to '`echo $REBRAND | $AWK -F "/" '{print $NF}' | $AWK -F "." '{print $1}'` 37)*"
fi
  echo -e "****************************************"
  pause
}

##########################################################################################

echo 
echo -e "***************************************************"
echo -e "*                                                 *"
echo -e "*      HWOTA7 for P9-EVA made by @Tecalote xda    *"
echo -e "*                                                 *"
echo -e "***************************************************"
echo 

if [ "`echo $ROOTPATH | grep ' '`" != "" ]; then
  pause "This script does not support a directory with space."
  exit
fi

if [ ${#ROOTPATH} -gt 200 ]; then
  pause "Путь слишком длинный, извлеките пакет сценариев по более короткому пути."
  exit
fi


pause "Connect device with USB cable to PC, restart phone and hold down VOL- to boot into fastboot mode."
wait_fastboot

# Get product, model, and build
PRODUCT=`$FASTBOOT oem get-product-model 2>&1 | grep bootloader | $AWK '{ print $2 }'`
MODEL=`echo $PRODUCT | $AWK -F "-" '{ print $1 }'`
BUILD=`$FASTBOOT oem get-build-number 2>&1 | grep bootloader | $AWK -F ":" '{ print $2 }' | $AWK -F "\r" '{ print $1 }'`

unlock_device "Keep USB cable connected, wait for the phone to boot into system. Enable ADB/USB Debugging, reboot phone with Power Button and VOL- into fastboot mode."
wait_fastboot

TWRP_FILE=`cd $RECPATH/EVA; ls | grep -i twrp`
TWRP=$RECPATH/EVA/$TWRP_FILE
echo
echo -e "Replacing the eRecovery runoff in TWRP, wait..."
$FASTBOOT flash recovery2 $TWRP
echo
pause "Hold down the volume key plus and Power Button to boot into TWRP."
pause "Wait for the device to boot into TWRP."

wait_adb

while [ 1 ]
do
echo 
echo -e "****************************************"
echo -e "* Upgrade options :                    *"
echo -e "*   1. From the SD card                *"
echo -e "*   2. Using the script                *"
echo -e "****************************************"
echo -n "Select: "
UPDATE_SOURCE=$(getkeys)
if [ $(isnum $UPDATE_SOURCE) -eq 1 ] && [ "$UPDATE_SOURCE" -gt "0" ] && [ "$UPDATE_SOURCE" -lt "3" ]; then
  break
fi
echo -e "Wrong select..."
done

  FRP_FILE=`cd $RECPATH/EVA; ls | grep -i frp`
  RECOVERY_FILE=EVA_RECOVERY_NoCheck.img
  FRP=$RECPATH/EVA/$FRP_FILE
  RECOVERY=$RECPATH/EVA/$RECOVERY_FILE
  FRP_TMP=/tmp/$FRP_FILE
  RECOVERY_TMP=/tmp/$RECOVERY_FILE
  UPDATE_FILE=update.zip
  UPDATE_DATA_FILE=update_data_public.zip
  UPDATE_HW_FILE=update_all_hw.zip

if [ "$UPDATE_SOURCE" -eq "1" ]; then # SDCard
  SOURCE_PATH=
  SOURCE_UPDATE=
  SOURCE_UPDATE_DATA=
  SOURCE_UPDATE_HW=
  TARGET_PATH=/sdcard/HWOTA
  TARGET_UPDATE=$TARGET_PATH/$UPDATE_FILE
  TARGET_UPDATE_DATA=$TARGET_PATH/$UPDATE_DATA_FILE
  TARGET_UPDATE_HW=$TARGET_PATH/$UPDATE_HW_FILE
else # internal
  SOURCE_PATH=$ROOTPATH/update
  SOURCE_UPDATE=$SOURCE_PATH/$UPDATE_FILE
  SOURCE_UPDATE_DATA=$SOURCE_PATH/$UPDATE_DATA_FILE
  SOURCE_UPDATE_HW=$SOURCE_PATH/$UPDATE_HW_FILE
  TARGET_PATH=/data/update/HWOTA
  TARGET_UPDATE=$TARGET_PATH/$UPDATE_FILE
  TARGET_UPDATE_DATA=$TARGET_PATH/$UPDATE_DATA_FILE
  TARGET_UPDATE_HW=$TARGET_PATH/$UPDATE_HW_FILE
fi


while [ 1 ]
do
  echo 
  echo -e "****************************************"
  echo -e "* What would you like to do?           *"
  echo -e "*   1. Change firmware                 *"
  echo -e "*   2. Change location                 *"
  echo -e "****************************************"
  echo -n "Select: "
  UPDATE_TYPE=$(getkeys)
  if [ $(isnum $UPDATE_TYPE) -eq 1 ] && [ "$UPDATE_TYPE" -gt "0" ] && [ "$UPDATE_TYPE" -lt "3" ]; then
    break
  fi
  echo -e "Wrong select..."
done

if [ "$UPDATE_TYPE" = "1" ]; then
  list_config
fi

if [ "$UPDATE_TYPE" = "2" ]; then
  idx=0
  flist=($(ls $OEMPATH/$MODEL/* | sort))
  fsize=${#flist[@]}
  while [ 1 ]
  do
    idx=1
    echo 
    echo -e "**************************************** "
    echo "* File replacement oeminfo:            *"
    for oem in "${flist[@]}"
    do
      echo -e "* $(format_str $idx.' '`echo $oem | $AWK -F "/" '{print $NF}' | $AWK -F "." '{print $1}'` 37)* "
      idx=$(( idx + 1 ))
    done
    echo -e "**************************************** "
    echo -n "Select: "
    rb=$(getkeys)
    if [ $(isnum $rb) -eq 1 ] && [ "$rb" -gt "0" ] && [ "$rb" -lt "$(( fsize + 1 ))" ]; then
      break
    fi
    echo "Make a choice..."
  done
  REBRAND=${flist[$(( rb - 1 ))]}
  list_config
  echo 
  echo -e "Replacing the oeminfo file with the selected one, please wait ..."
  $ADB push $REBRAND /tmp/oeminfo
  $ADB push $FRP $FRP_TMP
  $ADB shell "dd if=$FRP_TMP of=/dev/block/mmcblk0p4"
  $ADB shell "dd if=/tmp/oeminfo of=/dev/block/platform/hi_mci.0/by-name/oeminfo"
    $ADB reboot bootloader
  wait_fastboot
  echo
  unlock_device "After factory reset, when the device reboots press VOL+ to boot TWRP instead of system!!!."
fi

echo
echo -e "Wait for the files to load. Dont press any button now!!!."
echo

wait_adb

if [ "$UPDATE_SOURCE" = "2" ]; then
  $ADB shell "rm -fr $TARGET_PATH > /dev/null 2>&1"
  $ADB shell "mkdir $TARGET_PATH > /dev/null 2>&1"
  echo -e "Copying is in progress ...."
  $ADB push $SOURCE_UPDATE $TARGET_UPDATE
  echo
  echo -e "Copying is in progress ...."
  $ADB push $SOURCE_UPDATE_DATA $TARGET_UPDATE_DATA
  echo
  echo -e "Copying is in progress ...."
  $ADB push $SOURCE_UPDATE_HW $TARGET_UPDATE_HW
fi

echo
echo -e "Copying recovery files, please be patient and wait...."
$ADB push $RECOVERY $RECOVERY_TMP
$ADB shell "dd if=$RECOVERY_TMP of=/dev/block/mmcblk0p29 bs=1048576"
$ADB shell "dd if=$RECOVERY_TMP of=/dev/block/mmcblk0p22 bs=1048576"
$ADB shell "echo --update_package=$TARGET_UPDATE > /cache/recovery/command"
$ADB shell "echo --update_package=$TARGET_UPDATE_DATA >> /cache/recovery/command"
$ADB shell "echo --update_package=$TARGET_UPDATE_HW >> /cache/recovery/command"
$ADB reboot recovery
$ADB kill-server

echo
pause "The system update should start automatically."

