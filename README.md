# tmimport
    Time Machine Importer

    tmimport.sh <backup drive>

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
    
# dirdedupe
    Directory De-Duplication ("Dirty Dupe")

    dirdedupe.sh [--execute] masterdir shadowdir

    For each file in shadowdir, replace it with a hard link to the matching file
    (if any) in masterdir.  A file will be considered a match if, and only if, it
    shares the same file name, relative path, and contents.

    OPTIONS

       --execute  Actually remove and link duplicate files. By default, this 
                  program runs in test mode. 