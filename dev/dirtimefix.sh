#!/usr/bin/env bash

# DIRECTORY TIME FIX
#
# Copyright (c) 2023 Joshua Lee Ockert <torstenvl@gmail.com>
#
# THIS WORK IS PROVIDED "AS IS" WITH NO WARRANTY OF ANY KIND. THE IMPLIED
# WARRANTIES OF MERCHANTABILITY, FITNESS, NON-INFRINGEMENT, AND TITLE ARE
# EXPRESSLY DISCLAIMED. NO AUTHOR SHALL BE LIABLE UNDER ANY THEORY OF LAW
# FOR ANY DAMAGES OF ANY KIND RESULTING FROM THE USE OF THIS WORK.
#
# Permission to use, copy, modify, and/or distribute this work for any
# purpose is hereby granted, provided this notice appears in all copies.


############################################################################
##                  FUNCTION TO PRINT USAGE INSTRUCTIONS                  ##
############################################################################
printusage() {
    echo "
DIRECTORY TIME FIX

USAGE

    dirtimefix.sh [--execute] <topdir> <minutes>

DESCRIPTION

    For each directory in <topdir> with a modification time within the past
    <minutes> minutes, reset its modification time (via touch -r) to match
    the newest file it contains.

OPTIONS

    --execute  Actually reset modification times. By default, this program
               runs in test mode. 
"
}


############################################################################
##                   PARSE & MAKE SENSE OF COMMAND LINE                   ##
############################################################################

# CHECK FOR THE EXECUTE FLAG (DEFAULT IS TESTING-ONLY MODE)
REALLYRUN=0
if [ "${1}" == "--execute" ]; then
    REALLYRUN=1
    shift
fi

EMTPYDIRS=""

# MAKE SURE WE HAVE THE RIGHT NUMBER OF ARGUMENTS AND THEY'RE VALID
if [ ! $# -eq 2 ]; then
    echo && echo "Wrong number of arguments!" && printusage && exit
else
    topdir=$1
    minutes=$2
    if [ ! -d "${topdir}" ]; then
        echo && echo "${topdir} is not a directory!" && printusage && exit
    elif [[ ! "${minutes}" =~ ^[0-9]+$ ]]; then
        echo && echo "${minutes} is not a whole number of minutes!" && printusage && exit
    fi
fi


############################################################################
##                   ADJUST MODIFICATION TIMES (OR NOT)                   ##
############################################################################
echo find "${topdir}" -type d -mtime -"${minutes}"m -d
find "${topdir}" -type d -mtime -"${minutes}"m -d -print0 | while read -d $'\0' moddir
do
    srchdir="${moddir}"
    newest=$(find "${srchdir}" \( -type d -or -type f \) -mtime +"${minutes}"m -mindepth 1 -maxdepth 1 -exec ls -td {} + | head -1)
    if [ "${newest}" == "" ]; then
        newest=$(find "${srchdir}/.." \( -type d -or -type f \) -mtime +"${minutes}"m -mindepth 1 -maxdepth 1 -exec ls -td {} + | head -1)
        if [ "${newest}" == "" ]; then
            newest=$(find "${srchdir}/../.." \( -type d -or -type f \) -mtime +"${minutes}"m -mindepth 1 -maxdepth 1 -exec ls -td {} + | head -1)
            if [ "${newest}" == "" ]; then
                newest=$(find "${srchdir}/../../.." \( -type d -or -type f \) -mtime +"${minutes}"m -mindepth 1 -maxdepth 1 -exec ls -td {} + | head -1)
                if [ "${newest}" == "" ]; then
                    newest=$(find "${srchdir}/../../../.." \( -type d -or -type f \) -mtime +"${minutes}"m -mindepth 1 -maxdepth 1 -exec ls -td {} + | head -1)
                    if [ "${newest}" == "" ]; then
                        echo "EMPTY DIR AT ${moddir}! Could not find a file to borrow mtime from!"
                    fi
                fi
            fi
        fi
    fi
    if [ ! "${newest}" == "" ]; then
        if [ $REALLYRUN -gt 0 ]; then
            echo "Setting mtime of \"${moddir}\" to mtime of \"${newest}\""
            touch -r "${newest}" "${moddir}"
        else
            echo "NOT setting mtime of \"${moddir}\" to mtime of \"${newest}\""
       fi
    fi
done

exit

