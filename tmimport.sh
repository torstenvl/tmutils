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
Time Machine Importer"
  echo
  echo "\
Usage: ${0} <backup drive>

Time Machine Importer modifies the metadata of a backup drive to match the 
current computer's model and unique identifiers (primary MAC address and
hardware platform UUID/provisioning UDID), attempts to associate the primary
disk with the backup, and attempts to 'inherit' the backup history.

The backup drive should be specified by volume name or mount point. If the
backup drive is specified by the disk device name or path, Time Machine
Importer will try to find an HFS+ partition on it. If there is one, or if a
partition name or path is specified, Time Machine Importer will attempt to
find the mount point and check for the existence of a Backups.backupdb
folder. 

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
        # TODO: Should check to see if it CONTAINS any disks with a Time Machine role...
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
    BACKUPPATH=`find $(stat -f %R ${1}) -type d -maxdepth 1 -xattrname com.apple.backupd.HostUUID -print -quit`
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
#UUIDHEX=`printf '%s\0' ${UUID} | xxd -p -c37`
MAC=`ifconfig en0 | awk '/ether/{print $2}'`
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

printf "Attributes are now:\n"
printf "    %s\t\t\t%s\n" "com.apple.backupd.ModelID" "$(xattr -p 'com.apple.backupd.ModelID' "${BACKUPPATH}")"
printf "    %s\t%s\n" "com.apple.backupd.BackupMachineAddress" "$(xattr -p 'com.apple.backupd.BackupMachineAddress' "${BACKUPPATH}")"
printf "    %s\t\t\t%s\n\n" "com.apple.backupd.HostUUID" "$(xattr -p 'com.apple.backupd.HostUUID' "${BACKUPPATH}")"

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

printf "\nDoes everything look right?\n\n"

select response in "Apply Time Machine Magic" "ABORT ABORT ABORT!"; do
    if [ "${response}" == "Apply Time Machine Magic" ]; then
        "${SIMONSAYS}" xattr -w 'com.apple.backupd.ModelID'              "${MODEL}" "${BACKUPPATH}"
        "${SIMONSAYS}" xattr -w 'com.apple.backupd.BackupMachineAddress' "${MAC}"   "${BACKUPPATH}"
        "${SIMONSAYS}" xattr -w 'com.apple.backupd.HostUUID'             "${UUID}"  "${BACKUPPATH}"
        "${SIMONSAYS}" tmutil inheritbackup "${BACKUPPATH}"
        printf "\nOperation completed.\n\n"
        printf "Attributes are now:\n"
        printf "    %s\t\t\t%s\n" "com.apple.backupd.ModelID" "$(xattr -p 'com.apple.backupd.ModelID' "${BACKUPPATH}")"
        printf "    %s\t%s\n" "com.apple.backupd.BackupMachineAddress" "$(xattr -p 'com.apple.backupd.BackupMachineAddress' "${BACKUPPATH}")"
        printf "    %s\t\t\t%s\n\n" "com.apple.backupd.HostUUID" "$(xattr -p 'com.apple.backupd.HostUUID' "${BACKUPPATH}")"
        break
    else
        printf "\nOperation aborted. No action has been taken.\n\n"
        break
    fi
done
