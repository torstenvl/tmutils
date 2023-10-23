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


############################################################################
##                  FUNCTION TO PRINT USAGE INSTRUCTIONS                  ##
############################################################################
printusage() {
    echo "
DIRECTORY DE-DUPLICATOR

USAGE

    dirdedupe.sh [--execute] masterdir subjectdir

DESCRIPTION

    For each file in subjectdir, replace it with a hard link to the matching
    file (if any) in masterdir.  A file will be considered a match if, and
    only if, it shares the same file name, relative path, and contents.

OPTIONS

    --execute  Actually remove and link duplicate files. By default, this 
               program runs in test mode. 

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

# MAKE SURE WE HAVE THE RIGHT NUMBER OF ARGUMENTS AND THEY'RE VALID
if [ ! $# -eq 2 ]; then
  echo && echo "Wrong number of arguments!" && printusage && exit
else
  masterdir=$1
  subjectdir=$2
  if [ ! -d "${masterdir}" ]; then
    echo && echo "${masterdir} is not a directory!" && printusage && exit
  elif [ ! -d "${subjectdir}" ]; then
    echo && echo "${subjectdir} is not a directory!" && printusage && exit
  fi
fi

############################################################################
##            MAKE A TEMPORARY FILE FOR PRESERVING TIMESTAMPS             ##
############################################################################
TEMPFILE = $(mktemp)
trap "rm -f ${TEMPFILE}" EXIT

############################################################################
##                    HARDLINK THE DUPLICATES (OR NOT)                    ##
############################################################################
find "${subjectdir}" -print0 | while read -d $'\0' subjectfile
do
    if [ -f "${subjectfile}" ]; then
        masterfile="${subjectfile/#${subjectdir}/${masterdir}}"
        if [ -f "${masterfile}" ]; then
            if [ ! "${subjectfile}" -ef "${masterfile}" ]; then
                cmp -s "${masterfile}" "${subjectfile}"
                if [ $? -eq 0 ]; then
                    if [ $REALLYRUN -gt 0 ]; then
                        echo "LINK \"${masterfile}\" <-- \"${subjectfile}\""
                        # Store the mtime/atime of subject file's directory
                        TEMPSUBJDIR=`dirname "${subjectfile}"`
                        #touch -r "${TEMPSUBJDIR}" "${TEMPFILE}"
                        # Link the subject file to the corresponding file in
                        # the master directory
                        ln -Pf "${masterfile}" "${subjectfile}"
                        # Restore the mtime/atime of subject file's directory
                        #touch -r "${TEMPFILE}" "${TEMPSUBJDIR}"
                    else
                        echo "HYPO \"${masterfile}\" <~~ \"${subjectfile}\""
                        TEMPSUBJDIR=`dirname "${subjectfile}"`
                        echo "   Saving atime/mtime of |${TEMPSUBJDIR}|"
                    fi
                #else
                    #echo "MOD  \"${masterfile}\" <X> \"${subjectfile}\""
                fi #END check for files being the same
            #else
                #echo "ID   \"${masterfile}\" <-> \"${subjectfile}\""
            fi # END check for inode equality
        #else
            #echo "NEW  \"${subjectfile}\" "
        fi # END check if master file exists
    fi
done

exit

