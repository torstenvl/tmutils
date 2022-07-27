**Time Machine Utilities**
==========================


**Installation**
----------------
Simply save the utility in your system path and mark it as executable.

If you don't know your system path, you can find it with this Terminal command:

    echo "${PATH}"

To mark a utility as executable, use the `chmod` command:

    chmod +x tmimport.sh
    chmod +x dirdedupe.sh

If you're still lost, do this:
  1. In your Home folder, create a new folder called `.bin`
  2. Download and save the utilities to your new `.bin` folder
  3. Use a text editor to open `.zshrc` (or `.bash_profile` on older Macs)
     from your Home folder and add the following line at the end:

     `PATH=${PATH}:${HOME}/.bin`

  4. In Terminal, run the following commands:

     `chmod +x ~/.bin/*.sh`

  5. Quit (or restart) the Terminal.
   
______________________________________________________________________________


**tmimport**
------------
    TIME MACHINE IMPORT

    USAGE
    
        tmimport.sh <backup drive>
    
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
______________________________________________________________________________


**tmbless**
------------
    TIME MACHINE BLESS
    
    USAGE
    
        tmbless.sh <snapshot directory>
    
    DESCRIPTION
    
        Time Machine Blessing modifies the metadata of a snapshot directory
        (i.e., a datestamped directory inside a Backups.backupdb/machinename/
        directory) so that the metadata reflects a backup completed on that date
        and the metadata of the top-level drive matches that of the current drive.
    
        These modifications should allow restoration of files within the Time
        Machine restore UI. 
______________________________________________________________________________


**dirdedupe**
-------------
    DIRECTORY DE-DUPLICATOR

    USAGE
    
        dirdedupe.sh [--execute] masterdir shadowdir

    DESCRIPTION

        For each file in shadowdir, replace it with a hard link to the matching file
        (if any) in masterdir.  A file will be considered a match if, and only if,
        it shares the same file name, relative path, and contents.

    OPTIONS

        --execute  Actually remove and link duplicate files. By default, this 
                   program runs in test mode. 
