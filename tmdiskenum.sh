#!/usr/bin/env bash


function storebackupdrivelist() {
  
  # Search for external drives
  local ext_drv_srch=`diskutil list | grep external`
  local ext_drv_list=`diskutil list | grep external | sed 's/.*\(disk[0-9][0-9]*\).*/\1/g'`
  
  # Then, for each one...
  for drivename in $ext_drv_list; do
    # Get the HFS partitions
    local ext_hfs_ptns=`diskutil list ${drivename} | grep "Apple_HFS" | grep "${drivename}" | cut -w -f7`
    # And get their volume names, mount points, and mount status
    for partitionname in $ext_hfs_ptns; do
      local volumename=`diskutil info /dev/${partitionname} | grep "Volume Name:" | cut -w -f4`
      local mountpoint=`diskutil info /dev/${partitionname} | grep "Mount Point:" | cut -w -f4`
      if [ mountpoint == "" ]; then
        mountpoint="(none)"
        local mountstatus="NO"
      else 
        local mountstatus="YES"
      fi
      if [ ${#drives[@]} -eq 0 ]; then 
        drives=("${partitionname}")
      else 
        drives=("${drives[@]}","${partitionname}")
      fi
      drives=("${drives[@]}","${volumename}")
      drives=("${drives[@]}","${mountstatus}")
      drives=("${drives[@]}","${mountpoint}")
      drives=("${drives[@]}","EOL")
    done
  done
}

declare -a drives
storebackupdrivelist drives

echo "drives = ${drives}"
