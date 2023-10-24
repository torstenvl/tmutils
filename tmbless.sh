#!/usr/bin/env bash

# Copyright (c) 2023 Joshua Lee Ockert <torstenvl@gmail.com>
#
# THIS WORK IS PROVIDED "AS IS" WITH NO WARRANTY OF ANY KIND. THE IMPLIED
# WARRANTIES OF MERCHANTABILITY, FITNESS, NON-INFRINGEMENT, AND TITLE ARE
# EXPRESSLY DISCLAIMED. NO AUTHOR SHALL BE LIABLE UNDER ANY THEORY OF LAW
# FOR ANY DAMAGES OF ANY KIND RESULTING FROM THE USE OF THIS WORK.
#
# Permission to use, copy, modify, and/or distribute this work for any
# purpose is hereby granted, provided this notice appears in all copies.
#
# SPDX-License-Identifier: ISC


function dispusage() {
  if [ ${#1} -gt 0 ]; then
    printf "%s\n\n" "${1}"
  fi
  echo "\
TIME MACHINE BLESS

USAGE

    ${0} <snapshot directory>

DESCRIPTION

    Time Machine Bless marks a snapshot directory as valid and recognizable
    by Time Machine.

    It does this by modifying the metadata of the snapshot directory so that
    the it accurately reflects the date the snapshot was created and the
    metadata of the 'drive' subdirectory within that snapshot directory
    matches the current drive.

    These modifications should allow restoration of files within the Time
    Machine restore UI. 
"
}

function canonicalname() {
    echo $(stat -f %R ${1})
}

############################################################################
##                   PARSE & MAKE SENSE OF COMMAND LINE                   ##
############################################################################
if [ ! $# -eq 1 ]; then
  dispusage "Invalid number of arguments" && exit
fi

# Try to get canonical name
DATEDIRNAME=$(stat -f %R ${1})
if [[ "${DATEDIRNAME}" == "" ]]; then
    dispusage "Could not get canonical name of directory ${1}" && exit
fi

# Ensure it's a directory
if [ ! -d "${DATEDIRNAME}" ]; then
    dispusage "${DATEDIRNAME} is not a valid directory" && exit
fi 

# Ensure it's a Backups.backupdb dir's subdir's subdir
if [[ ! "${DATEDIRNAME}" =~ ^.*\/Backups\.backupdb\/.*\/.*$ ]]; then
    dispusage "${DATEDIRNAME} does not appear to be in a Backups.backupdb directory" && exit
fi

# Get the basename and ensure it's in a Time Machine timestamp format
DATEDIRBASENAME=$(basename "${DATEDIRNAME}")
if [[ ! "${DATEDIRBASENAME}" =~ ^[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]-[0-9][0-9][0-9][0-9][0-9][0-9]\/?$ ]]; then
    dispusage "${DATEDIRBASENAME} does not appear to be a snapshot directory" && exit
fi

# Get the Unix timestamp from the directory's Time Machine timestamp format
TIMESTAMP=$(date -j -f "%Y-%m-%d-%H%M%S" "${DATEDIRBASENAME}" +"%s")
TIMESTAMP="${TIMESTAMP}100000"
if [[ ! "${TIMESTAMP}" =~ ^[0-9]*$ ]]; then
    dispusage "Could not automatically set snapshot timestamp due to folder name format" && exit
fi

if [ -d "${DATEDIRNAME}/Macintosh HD - Data" ]; then
    DRVDIRNAME="${DATEDIRNAME}/Macintosh HD - Data"
elif [ -d "${DATEDIRNAME}/Macintosh HD" ]; then
    DRVDIRNAME="${DATEDIRNAME}/Macintosh HD"
else
    ## TODO: Take the output of `ls -d ${DATEDIRNAME}` and try to autodetect?
    dispusage "Could not find a volume name within ${DATEDIRNAME}" && exit
fi

############################################################################
##                    GET NECESSARY SYSTEM INFORMATION                    ##
############################################################################
VOLGRPUUID=`diskutil info / | awk -F' ' '/^   APFS Volume Group/{print $(NF)}'`
VOLDSKUUID=`diskutil info / | awk -F' ' '/^   Volume UUID/{print $(NF)}'`

if [ ! VOLGRPUUID == "" ]; then
   TGTUUID="${VOLGRPUUID}"
elif [ ! VOLDSKUUID == "" ]; then
   TGTUUID="${VOLDSKUUID}"
fi


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
Snapshot Directory:  %s\n\
Snapshot Volume:     %s\n\
Computer Volume:     %s\n\
   Volume Group:     %s\n\\n" "${DATEDIRNAME}" "${DRVDIRNAME}" "${VOLDSKUUID}" "${VOLGRPUUID}"

printf "\
Preparing to run the following commands:\n\
    %s xattr -c \"%s\"\n\
    %s xattr -c \"%s\"\n\
    %s xattr -w \"com.apple.backupd.SnapshotCompletionDate\" \"%s\" \"%s\"\n\
    %s xattr -w \"com.apple.backupd.SnapshotState\" %s \"%s\"\n\
    %s xattr -w \"com.apple.backupd.SnapshotVolumeUUID\" \"%s\" \"%s\"\n\
    \n" "${SIMONSAYS}"  "${DATEDIRNAME}" \
        "${SIMONSAYS}"  "${DRVDIRNAME}" \
        "${SIMONSAYS}"  "${TIMESTAMP}"   "${DATEDIRNAME}" \
        "${SIMONSAYS}"  "4"              "${DATEDIRNAME}" \
        "${SIMONSAYS}"  "${TGTUUID}"     "${DRVDIRNAME}"

printf "Does everything look right?\n"

select response in "Bless Time Machine Snapshot" "ABORT ABORT ABORT!"; do
    if [ "${response}" == "Bless Time Machine Snapshot" ]; then
        "${SIMONSAYS}" xattr -c "${DATEDIRNAME}" && \
        "${SIMONSAYS}" xattr -c "${DRVDIRNAME}" && \
        "${SIMONSAYS}" xattr -w "com.apple.backupd.SnapshotCompletionDate" "${TIMESTAMP}" "${DATEDIRNAME}" && \
        "${SIMONSAYS}" xattr -w "com.apple.backupd.SnapshotState" "4" "${DATEDIRNAME}" && \
        "${SIMONSAYS}" xattr -w "com.apple.backupd.SnapshotVolumeUUID" "${TGTUUID}" "${DRVDIRNAME}"

        if [ ! $? -eq 0 ]; then
            printf "\nOperation failed.\n\n"
        else
            printf "\nOperation completed.\n\n"
            printf "The snapshot directory now has the following metadata:\n"
            printf "%s\n" "——————————————————————————————————————————————————————"
            xattr -lv "${DATEDIRNAME}"
            printf "\n\n"
            printf "The snapshot volume now has the following metadata:\n"
            printf "%s\n" "———————————————————————————————————————————————————"
            xattr -lv "${DRVDIRNAME}"
            printf "\n\n"
        fi
        break
    else
        printf "\nOperation aborted. No action has been taken.\n\n"
        break
    fi
done
