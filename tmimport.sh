#!/usr/bin/env bash

# BITSC LICENSE NOTICE (MODIFIED ISC LICENSE)
#
# TIME MACHINE IMPORTER
#
# Copyright (c) 2022 Lee Ockert <torstenvl@gmail.com>
#                    https://github.com/torstenvl
#
# THIS WORK IS PROVIDED "AS IS" WITH NO WARRANTY OF ANY KIND. THE IMPLIED
# WARRANTIES OF MERCHANTABILITY, FITNESS, NON-INFRINGEMENT, AND TITLE ARE
# EXPRESSLY DISCLAIMED. NO AUTHOR SHALL BE LIABLE UNDER ANY THEORY OF LAW
# FOR ANY DAMAGES OF ANY KIND RESULTING FROM THE USE OF THIS WORK.
#
# Permission to use, copy, modify, and/or distribute this work for any
# purpose is hereby granted, provided this notice appears in all copies.


function dispusage() {
  if [ ${#1} -gt 0 ]; then
    printf "%s\n\n" "${1}"
  fi
  echo "\
TIME MACHINE IMPORT

USAGE

    ${0} <backup drive>

DESCRIPTION

    Time Machine Importer modifies the metadata of a backup drive to match the 
    current computer's model and unique identifiers (primary MAC address and
    hardware platform UUID/provisioning UDID) and attempts to 'inherit' the
    backup history.

    The backup drive should be specified by disk or volume name (or path) or
    the mount point of the backup drive. If Time Machine Importer cannot find
    an appropriate disk volume or mount point, it will check to see if the 
    specified directory is a valid Backups.backupdb location (or a machine
    directory under one).

    A future version may attempt to detect HFS+ or APFS partitions serving as
    backup drives, and, if a backup drive is specified as a device path, it
    will automagically choose the correct backup path.

"
}


############################################################################
##                   PARSE & MAKE SENSE OF COMMAND LINE                   ##
############################################################################
if [ ! $# -eq 1 ]; then
  dispusage "Invalid number of arguments" && exit
fi

## IF USER PROVIDED A VALID DEVICE, VOLUME NAME, OR MOUNT POINT, USE THAT
diskutil list "${1}" > /dev/null 2>&1 
if [[ $? -eq 0 ]]; then
    MOUNTPOINT=`diskutil info ${1} | grep "Mount Point:" | sed 's/^ *Mount Point: *\(.*\)$/\1/'`
    if [ "${MOUNTPOINT}" == "" ]; then
        dispusage "No mount point for specified device ${1}. Perhaps it isn't mounted?" && exit
        ######################################################################################
        ##  TODO: Should check to see if it CONTAINS any disks with a Time Machine role...  ##
        ######################################################################################
    fi

    if [ ! -d "${MOUNTPOINT}/Backups.backupdb/" ]; then
        dispusage "No Backups.backupdb directory found at ${MOUNTPOINT}/Backups.backupdb/" && exit
    fi 

    BACKUPPATH=`find ${MOUNTPOINT}/Backups.backupdb -type d -maxdepth 1 -xattrname com.apple.backupd.HostUUID -print -quit`
    if [ "${BACKUPPATH}" == "" ]; then
        dispusage "No suitable backups within ${MOUNTPOINT}/Backups.backupdb!" && exit
    fi
    SPECIFIED="${1}"

## OTHERWISE, THE USER MAY HAVE PROVIDED A BACKUPS.BACKUPDB PATH
elif [[ -d "${1}" ]] && [[ $(stat -f %R ${1}) =~ Backups.backupdb$ ]]; then
    BACKUPPATH=`find $(stat -f %R ${1}) -type d -mindepth 1 -maxdepth 1 -xattrname com.apple.backupd.HostUUID -print -quit`
    if [ "${BACKUPPATH}" == "" ]; then
        dispusage "No suitable backups within $(stat -f %R ${1})!" && exit
    fi
    SPECIFIED=$(stat -f %R ${1})

## OR MAYBE EVEN THE DIRECTORY WITHIN IT
elif [[ -d "${1}" ]] && [[ $(stat -f %R ${1}) =~ Backups.backupdb\/.+$ ]]; then
    BACKUPPATH=`find $(stat -f %R ${1}) -type d -maxdepth 0 -xattrname com.apple.backupd.HostUUID -print -quit`
    if [ "${BACKUPPATH}" == "" ]; then
        dispusage "No suitable backups at $(stat -f %R ${1})!" && exit
    fi
    SPECIFIED=$(stat -f %R ${1})

## OTHERWISE WE'RE SCREWED
else
    dispusage "${1} is not a valid device, volume, or Backups.backupdb path." && exit
fi


############################################################################
##                    GET NECESSARY SYSTEM INFORMATION                    ##
############################################################################
MODEL=`ioreg -d2 -k IOPlatformUUID | awk -F\" '/"model"/{print $(NF-1)}'`
UUID=`ioreg -d2 -k IOPlatformUUID | awk -F\" '/"IOPlatformUUID"/{print $(NF-1)}'`
MAC=`ifconfig en0 | awk '/ether/{print $2}'`
#UUIDHEX=`printf '%s\0' ${UUID} | xxd -p -c37`
#MACHEX=`printf '%s\0' ${MAC} | xxd -p`

KERNELVER=`uname -a | sed 's/.*Version \([0-9][0-9]*\).*/\1/g'`
if [ $KERNELVER -lt 20 ]; then
  SIMONSAYS="sudo /System/Library/Extensions/TMSafetyNet.kext/Contents/Helpers/bypass"
else
  SIMONSAYS="sudo"
fi


############################################################################
##                       CONFIRM ACTION INFORMATION                       ##
############################################################################
printf "\n\
Specified Backup:  %s\n\
Backup Location:   %s\n\
Computer Model:    %s\n\
Host UUID:         %s\n\
MAC Address:       %s\n\n" "${SPECIFIED}" "${BACKUPPATH}" "${MODEL}" "${UUID}" "${MAC}"

printf "This backup drive is currently matched to the following computer:\n"
printf "    ModelID:     %s\n"   "$(xattr -p 'com.apple.backupd.ModelID' "${BACKUPPATH}")"
printf "    MAC Address: %s\n"   "$(xattr -p 'com.apple.backupd.BackupMachineAddress' "${BACKUPPATH}")"
printf "    Host UUID:   %s\n\n" "$(xattr -p 'com.apple.backupd.HostUUID' "${BACKUPPATH}")"

printf "\
Preparing to run the following commands:\n\
    %s xattr -w 'com.apple.backupd.ModelID'              \"%-36s\" \"%s\"\n\
    %s xattr -w 'com.apple.backupd.BackupMachineAddress' \"%-36s\" \"%s\"\n\
    %s xattr -w 'com.apple.backupd.HostUUID'             \"%-36s\" \"%s\"\n\
    %s tmutil inheritbackup \"%s\"\n\
    \n" "${SIMONSAYS}"  "${MODEL}"  "${BACKUPPATH}" \
        "${SIMONSAYS}"  "${MAC}"    "${BACKUPPATH}" \
        "${SIMONSAYS}"  "${UUID}"   "${BACKUPPATH}" \
        "${SIMONSAYS}"  "${BACKUPPATH}"

if [ ! "$(basename "${BACKUPPATH}")" == "$(scutil --get ComputerName)" ]; then
    printf "#############################################################################\n"
    printf "##            W A R N I N G     W A R N I N G     W A R N I N G            ##\n"
    printf "#############################################################################\n"
    printf "\n"
    printf "The Backup Location DOES NOT MATCH your computer name.\n"
    printf "\n"
    printf "    Backup Location:        %s\n" "${BACKUPPATH}"
    printf "    Backup Computer Name:   %s\n" "$(basename "${BACKUPPATH}")"
    printf "    Current Computer Name:  %s\n" "$(scutil --get ComputerName)"
    printf "\n"
    printf "Only proceed if you are very certain of what you're doing!\n"
    printf "Even if successful, the Time Machine restore UI will be adversely affected.\n"
else
    printf "Does everything look right?\n"
fi    


select response in "Apply Time Machine Magic" "ABORT ABORT ABORT!"; do
    if [ "${response}" == "Apply Time Machine Magic" ]; then
        "${SIMONSAYS}" xattr -w 'com.apple.backupd.ModelID'              "${MODEL}" "${BACKUPPATH}"
        "${SIMONSAYS}" xattr -w 'com.apple.backupd.BackupMachineAddress' "${MAC}"   "${BACKUPPATH}"
        "${SIMONSAYS}" xattr -w 'com.apple.backupd.HostUUID'             "${UUID}"  "${BACKUPPATH}"
        "${SIMONSAYS}" tmutil inheritbackup "${BACKUPPATH}"
        if [ ! $? -eq 0 ]; then
            printf "\nOperation failed. Backup history not imported.\n\n"
        else
            printf "\nOperation completed.\n\n"
            printf "This backup drive has been matched to the following computer:\n"
            printf "    ModelID:     %s\n"   "$(xattr -p 'com.apple.backupd.ModelID' "${BACKUPPATH}")"
            printf "    MAC Address: %s\n"   "$(xattr -p 'com.apple.backupd.BackupMachineAddress' "${BACKUPPATH}")"
            printf "    Host UUID:   %s\n\n" "$(xattr -p 'com.apple.backupd.HostUUID' "${BACKUPPATH}")"
        fi
        break
    else
        printf "\nOperation aborted. No action has been taken.\n\n"
        break
    fi
done
