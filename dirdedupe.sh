#!/usr/bin/env bash

# BITSC LICENSE NOTICE (MODIFIED ISC LICENSE)
#
# DIRECTORY DE-DUPLICATION ("Dirty Dupe")
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


############################################################################
##                  FUNCTION TO PRINT USAGE INSTRUCTIONS                  ##
############################################################################
printusage() {
    echo "
DIRECTORY DE-DUPLICATION (\"Dirty Dupe\")

${0} [--execute] masterdir shadowdir

For each file in shadowdir, replace it with a hard link to the matching file
(if any) in masterdir.  A file will be considered a match if, and only if, it
shares the same file name, relative path, and contents.

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
  shadowdir=$2
  if [ ! -d "${masterdir}" ]; then
    echo && echo "${masterdir} is not a directory!" && printusage && exit
  elif [ ! -d "${shadowdir}" ]; then
    echo && echo "${shadowdir} is not a directory!" && printusage && exit
  fi
fi


############################################################################
##                    HARDLINK THE DUPLICATES (OR NOT)                    ##
############################################################################
find "${shadowdir}" -print0 | while read -d $'\0' shadowfile
do
    if [ -f "${shadowfile}" ]; then
      masterfile="${shadowfile/#${shadowdir}/${masterdir}}"
      if [ -f "${masterfile}" ]; then
        cmp -s "${masterfile}" "${shadowfile}"
        if [ $? -eq 0 ]; then
          if [ $REALLYRUN -gt 0 ]; then
            echo "Linking \"${masterfile}\" <-- \"${shadowfile}\""
            ln -Pf "${masterfile}" "${shadowfile}"
          else
            echo "NOT linking \"${masterfile}\" <-- \"${shadowfile}\""
          fi
        fi
      fi
    fi
done

exit

