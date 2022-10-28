#!/bin/bash
read -r -d '' USAGE <<'USAGE_STR'
Script to manage the RC5 content

Usage:  rc3 COMMAND [Arguments]                                                  

Suppored commands: 
    backup:   Save the entire content of the RC5 to a backup file
              First Param:     Directory to save the backup to. Defaults to current directory

    restore:  Restore a backup file unto the RC5
              First Param:     Name of the file to restore

    list:     List all the file and their location on the RC5

    listall:  List the content of all locations on the RC5, even the empty ones

    add:      [location] [filename] add the file to the memory locatio specified

    delete:   [location] remove the file at the specified location

    eject:    (NOT WORKING) Disconnect safely (Use: lshw -C disk ; df | grep [device] ; umount [mount point] ; eject [device]

    check:    Verifies that the RC5 is connected

    reset:    Erase all memory locations

    help:        Print this information.
USAGE_STR


BOSS_RC5='BOSS RC-5'
RC5_BASE_DIR="/media/$USER/$BOSS_RC5"
RC5_WAVE_DIR="$RC5_BASE_DIR/ROLAND/WAVE"

#------------------------------------------
#  Return the name of a dir from a num
#------------------------------------------
function num2dir()
{
    echo "$(printf %03d_1 $1)"
}

#------------------------------------------
# Return the file at a specific mem
#------------------------------------------
function file_at()
{
    # Make sure the file exist and is a WAV file
    MEMNUM=$1
    if [ -z "$MEMNUM" ] ; then
        return
    fi
 
    if [[ ! "$MEMNUM" -ge 1 && "$MEMNUM" -le 99 ]] ; then
        return
    fi
 
    # Checking destination
    DIRNAME="${RC5_WAVE_DIR}/$(num2dir $MEMNUM)"
    echo $(ls "$DIRNAME")
}

#-----------------------------------------
# Check that there is indeed a RC5 connected
#-----------------------------------------
function check_rc3_connected()
{
    if [[ ! -d "$RC5_WAVE_DIR" ]] ; then
        echo "RC5 not connected (at: $RC5_WAVE_DIR), connect and configure (Setup, Storate, Connecting)"
        exit 0
    fi
}

#-----------------------------------------
# Clean up the name to not include special
# characters or spaces
#-----------------------------------------
function cleanup()
{
   OLD_NAME="$1"

   #Cleanup operation
   NEW_NAME=$(basename "$OLD_NAME")
   NEW_NAME="${NEW_NAME%.*}"
   NEW_NAME="${NEW_NAME// /}"
   NEW_NAME="${NEW_NAME//\(/}"
   NEW_NAME="${NEW_NAME//\)/}"
   NEW_NAME="${NEW_NAME//\'/}"
   NEW_NAME="${NEW_NAME//\;/}"
   NEW_NAME="${NEW_NAME//\%/}"
   NEW_NAME="${NEW_NAME//\$/}"
   NEW_NAME="${NEW_NAME//\#/}"
   NEW_NAME="${NEW_NAME//\@/}"
   NEW_NAME="${NEW_NAME//\*/}"
   NEW_NAME="${NEW_NAME//\!/}"
   NEW_NAME="${NEW_NAME//-/_}"
   NEW_NAME="${NEW_NAME//,/_}"
   echo "${NEW_NAME^^}.wav"
}


#-----------------------------------------
# Backup to specified directory or current
#-----------------------------------------
function backup()
{
    check_rc3_connected
    BK_NAME=rc3_backup_`date +%Y%m%dT%H%M%S`.tar.gz
    BK_DIR=$1
    if [[ -z "$BK_DIR" ]] ; then
        BK_DIR=${PWD}
    else 
        if [ "${BK_DIR:0:1}" != "/" ] ; then
            BK_DIR=${PWD}/$BK_DIR
        fi
    fi

    echo -n "Backing up RC5 content to $BK_DIR (Y/n)? "
    read -r RESP
    if [ "$RESP" != "Y" ]; then
        echo "Exiting..."
        exit 0
    fi

    cd "$RC5_BASE_DIR"
    tar cvzf $BK_DIR/$BK_NAME .
}

#-----------------------------------------
# Restoring existing backup
#-----------------------------------------
function restore()
{
    check_rc2_connected
    echo "Restoring backup: $1"
}

#-----------------------------------------
# Check that the RC5 is connected
#-----------------------------------------
function check()
{
    check_rc3_connected
    echo "RC5 is connected (at: $RC5_WAVE_DIR)"
}


#-----------------------------------------
# List all files on the RC5
#-----------------------------------------
function list()
{
    check_rc3_connected
    for num in $(seq -w 1 99) ; do 
        DIR="0${num}_1" ; 
        FILE=$(ls "${RC5_WAVE_DIR}/${DIR}")
        if [[ -n "$FILE" ]] ; then
            echo "$num: $FILE"
        fi
    done
}

#-----------------------------------------
# List all files on the RC5, including empty spots
#-----------------------------------------
function listall()
{
    for num in $(seq -w 1 99) ; do 
        DIR="0${num}_1" ; 
        FILE=$(ls "$RC5_WAVE_DIR/$DIR")
        echo "$num: $FILE"
    done
}

#-----------------------------------------
# Disconnect RC5
#-----------------------------------------
function eject()
{
    echo "It is now safe to disconnect the RC5"
}

#-----------------------------------------
# Add a single file to the RC5
#-----------------------------------------
function add()
{
    # Make sure the file exist and is a WAV file
    MEMNUM=$1
    if [ -z "$MEMNUM" ] ; then
        echo "Provide the memory number you wish to use"
        exit 0
    fi
 
    if [[ ! "$MEMNUM" -ge 1 && "$MEMNUM" -le 99 ]] ; then
        echo "Number must be between 1 and 99 (inclusive)"
        exit 0
    fi
 
    # Checking destination
    DIRNAME="${RC5_WAVE_DIR}/$(num2dir $MEMNUM)"
    EXISTING_FILE=$(ls "$DIRNAME")
 
    if [[ -n "$EXISTING_FILE" ]] ; then
        delete $MEMNUM
    fi

    # Check source file
    ORIG_FILE="$2"
    CLEAN_WAV_FILE=$(cleanup "$2")
    SOURCE_FILE="$ORIG_FILE"

    if [[ ! -f "$ORIG_FILE" ]] ; then
        echo "File not found: \"$ORIG_FILE\""
        exit 0
    fi

    # Check source file format and convert if necessary
    if [[ $(file -b --mime-type "$ORIG_FILE") != "audio/x-wav" ]] ; then
        TMP_FILE="/tmp/$CLEAN_WAV_FILE"
        SOURCE_FILE="$TMP_FILE"
        sox "$ORIG_FILE" -e float -b 32 "$TMP_FILE" 
        # mpg123 -q -w "$TMP_FILE" "$ORIG_FILE"
        #ffmpeg -v 0 -y -i "$ORIG_FILE" "$TMP_FILE"
        if [[ $? != 0 ]] ; then
            echo "File conversion to wav failed"
            exit 1
        fi
    fi

    # Now copy the file
    echo -n "$MEMNUM: Adding $ORIG_FILE... "
    cp "$SOURCE_FILE" "$DIRNAME/$CLEAN_WAV_FILE"
    echo "Done"

    # Delete tmp file
    if [[ -f "$TMP_FILE" ]] ; then
        rm "$TMP_FILE"
    fi
}

#------------------------------------------
# Delete a single file on the RC5
#------------------------------------------
function delete()
{
    MEMNUM=$1

    if [ -z "$1" ] ; then
        echo "Provide the number of the file you wish to delete"
        exit 0
    fi
 
    if [[ ! "$MEMNUM" -ge 1 && "$MEMNUM" -le 99 ]] ; then
        echo "Number must be between 1 and 99 (inclusive)"
        exit 0
    fi
 
    DIRNAME="${RC5_WAVE_DIR}/$(num2dir $MEMNUM)"
    EXISTING_FILE=$(ls "$DIRNAME")
 
    if [[ -n "$EXISTING_FILE" ]] ; then
        echo "$MEMNUM: deleting $EXISTING_FILE"
        pushd "$DIRNAME" > /dev/null
        rm -f * .* > /dev/null 2>&1
        popd > /dev/null
    else
        echo "$MEMNUM: No file found"
    fi
}

#------------------------------------------
# Sync files from a sync file
#------------------------------------------
function sync()
{
    SYNC_FILE=$1
    SYNC_DIR=$(dirname "$SYNC_FILE")

    if [[ ! -f "$SYNC_FILE" ]] ; then
        echo "Sync file $SYNC_FILE not found"
        exit 0
    fi

    while IFS=':' read -r SYNC_MEM FILENAME ; do
        #echo "RAW: $SYNC_MEM, $FILENAME"
        FILENAME_TRIMMED=$(echo "$FILENAME" | sed 's/^ *//g')
        FILENAME_TRIMMED=$(echo "$FILENAME_TRIMMED" | sed 's/* $//g')
        FILEPATH="$SYNC_DIR/$FILENAME_TRIMMED"
        FILE_AT="$(file_at $SYNC_MEM)"
        CLEAN_FILE=$(cleanup "$FILENAME_TRIMMED")

        if [[ "$FILE_AT" == "$CLEAN_FILE" ]] ; then
            echo "$SYNC_MEM: keeping $FILENAME_TRIMMED"
        else
            if [[ -n "$FILE_AT" ]] ; then
                delete $SYNC_MEM 
            fi
            if [[ -n "$FILENAME_TRIMMED" ]] ; then
                add "$SYNC_MEM" "$FILEPATH"
            fi
        fi
    done < $SYNC_FILE 
}

#------------------------------------------
# Export all files and create a sync file
#------------------------------------------
function export()
{
    DEST_DIR=$1
    SYNC_FILE="sync.txt"

    if [[ -z "$DEST_DIR" ]]; then
        echo "Specify destination dir"
        exit 0
    fi

    if [[ ! -d "$DEST_DIR" ]]; then
        mkdir -p $DEST_DIR
    fi

    if [[ -f "$DEST_DIR/$SYNC_FILE" ]] ; then
        rm "$DEST_DIR/$SYNC_FILE"
    fi

    for num in $(seq 1 99) ; do 
        DIR="$(printf "%03d" $num)_1"
        FILE=$(ls "$RC5_WAVE_DIR/$DIR")
        if [[ -n "$FILE" ]] ; then
            CLEAN_FILE=$(cleanup "$FILE")
            if [[ ! -f "$DEST_DIR/$CLEAN_FILE" ]] ; then
                cp "$RC5_WAVE_DIR/$DIR/$FILE" "$DEST_DIR/$CLEAN_FILE"
            fi
            echo "$num: $CLEAN_FILE" >> "$DEST_DIR/$SYNC_FILE"
        else
            echo "$num: " >> "$DEST_DIR/$SYNC_FILE"
        fi
    done
}

#-------------------------------------------
# Remove everything on the RC#
#-------------------------------------------
function reset()
{
    echo -n "This operation will erase all content of RC5 (Y/n)? "
    read -r RESP
    if [ "$RESP" != "Y" ]; then
        echo "Exiting..."
        exit 0
    fi

    for num in $(seq -w 1 99) ; do 
        DIR="0${num}_1" ; 
        pushd "${RC5_WAVE_DIR}/${DIR}" > /dev/null
        rm -f * .*
        popd > /dev/null
    done
}



#--------------------------------------------------------------------------------
#            Read command                 
#--------------------------------------------------------------------------------
COMMAND="$1"
shift
case "$COMMAND" in
    backup | restore | check | eject | list | listall | add | delete | sync | export | reset)
      "$COMMAND" "$@"
    ;;
    help) 
      echo "$USAGE" 
    ;;
    *) 
      echo "Unknown command \"$COMMAND\""
      echo "$USAGE"
      exit 1 
    ;;
esac

exit 0
