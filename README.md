**Time Machine Utilities**
==========================

Time Machine Utilities consists of three shell scripts to assist in fixing some issues that may arise when trying to import and use older Time Machine backups, particularly those created on a previous Mac.

- `tmimport.sh` imports a Time Machine backup collection, including making the metadata of the backup collection match the current computer.
- `tmbless.sh` blesses an individual Time Machine backup, including making the metadata of the drive in the backup match the main drive of the current computer.
- `dirdedupe.sh` is an advanced utility to manually deduplicate files using hard links, similar to how Time Machine works internally. This is sometimes helpful when a previous backup was not yet imported when creating a new Time Machine backup.

**Installation**
----------------
Simply save the utilities in your path and mark them as executable.

If you don't know your system path, you can find it with this Terminal command:

    echo "${PATH}"

To mark a utility as executable, use the `chmod` command:

    chmod +x tmimport.sh
    chmod +x tmbless.sh
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
    
        Time Machine Importer attempts to inherit the backup history of a backup
        drive. If the backup drive is not paired to the current computer, Time
        Machine Importer will attempt to pair the drive with the current computer
        by modifying the model, MAC address, and UUID/UDID reflected in the
        metadata of the backup drive.

        The backup drive should be specified by disk or volume name (or path) or
        the mount point of the backup drive. For example:
            - ./tmimport.sh /dev/disk1s1
            - ./tmimport.sh /Volumes/TMBACKUP

        While some additional heuristics may assist in identifying a backup drive
        that is specified in other ways, they are untested and not guaranteed
        to work correctly.
______________________________________________________________________________


**tmbless**
------------
    TIME MACHINE BLESS
    
    USAGE
    
        tmbless.sh <snapshot directory>
    
    DESCRIPTION
    
        Time Machine Bless marks a snapshot directory as valid and recognizable
        by Time Machine.

        It does this by modifying the metadata of the snapshot directory so that
        the it accurately reflects the date the snapshot was created and the
        metadata of the 'drive' subdirectory within that snapshot directory
        matches the current drive.

        These modifications should allow restoration of files within the Time
        Machine restore UI. 
______________________________________________________________________________


**dirdedupe**
-------------
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

In the example below, you can see that running `dirdedupe.sh` results in the files being linked, while preserving the date and time stamps of the enclosing directories.

<img width="761" alt="dirdedupe example" src="https://github.com/torstenvl/tmutils/assets/19603155/f5a9166a-2058-4eb7-ab30-0ac64b6bdfbd">
