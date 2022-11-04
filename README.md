# Looper scripts
Usage:  rc3.sh (or rc5.sh) COMMAND [Arguments]

Suppored commands: 
* ***backup***:   Save the entire content of the RC5 to a backup file  
              First Param:     Directory to save the backup to. Defaults to current directory
* ***restore***:  Restore a backup file unto the RC5  
              First Param:     Name of the file to restore
* ***list***:     List all the file and their location on the RC5  
* ***listall***:  List the content of all locations on the RC5, even the empty ones
* ***add***:      [location] [filename] add the file to the memory locatio specified
* ***delete***:   [location] remove the file at the specified location
* ***eject***:    (NOT WORKING) Disconnect safely (Use: lshw -C disk ; df | grep [device] ; umount [mount point] ; eject [device]
* ***check***:    Verifies that the RC5 is connected
* ***reset***:    Erase all memory locations
* ***help***:        Print this information.
