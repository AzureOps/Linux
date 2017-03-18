#!/bin/bash

# You can customize it to work with other Linux flavours and versions.

# MOUNTPOINT="/log"
RAIDCHUNKSIZE=512

RAIDDISK="/dev/sde"
RAIDPARTITION="/dev/sde1"

# An set of disks to ignore from partitioning and formatting
BLACKLIST="/dev/sda|/dev/sdb"

check_os() {
    grep ubuntu /proc/version > /dev/null 2>&1
    isubuntu=${?}
    grep centos /proc/version > /dev/null 2>&1
    iscentos=${?}
}

scan_for_new_disks() {
    # Looks for unpartitioned disks
    declare -a RET
    DEVS=($(ls -1 /dev/sd*|egrep -v "${BLACKLIST}"|egrep -v "[0-9]$"))
    for DEV in "${DEVS[@]}";
    do
        # Check each device if there is a "1" partition.  If not,
        # "assume" it is not partitioned.
        if [ ! -b ${DEV}1 ];
        then
            RET+="${DEV} "
        fi
    done
    echo "${RET}"
}

get_disk_count() {
    DISKCOUNT=0
    for DISK in "${DISKS[@]}";
    do 
        DISKCOUNT+=1
    done;
    echo "$DISKCOUNT"
}


do_partition() {
# This function creates one (1) primary partition on the
# disk, using all available space
    DISK=${1}
    echo "Partitioning disk $DISK"
    echo "n
p
1


w
" | fdisk "${DISK}" 
#> /dev/null 2>&1

#
# Use the bash-specific $PIPESTATUS to ensure we get the correct exit code
# from fdisk and not from echo
if [ ${PIPESTATUS[1]} -ne 0 ];
then
    echo "An error occurred partitioning ${DISK}" >&2
    echo "I cannot continue" >&2
    exit 2
fi
}

do_gpt_partition() {

# This function creates one (1) primary partition on the
# disk, using all available space
    DISK=${1}
    echo "Partitioning disk $DISK"
    echo "mklabel gpt
mkpart primary ext4 0% 100%
print
set 1 raid on
q
" | parted -a optimal "${DISK}" 

#> /dev/null 2>&1
#
# Use the bash-specific $PIPESTATUS to ensure we get the correct exit code
# from fdisk and not from echo

if [ ${PIPESTATUS[1]} -ne 0 ];
then
    echo "An error occurred partitioning ${DISK}" >&2
    echo "I cannot continue" >&2
    exit 2
fi
}

add_to_fstab() {
    UUID=${1}
    MOUNTPOINT=${2}
    grep "${UUID}" /etc/fstab >/dev/null 2>&1
    if [ ${?} -eq 0 ];
    then
        echo "Not adding ${UUID} to fstab again (it's already there!)"
    else
        LINE="UUID=${UUID} ${MOUNTPOINT} ext4 defaults,noatime 0 0"
        echo -e "${LINE}" >> /etc/fstab
    fi
}

configure_disks() {
	ls "${MOUNTPOINT}"
	if [ ${?} -eq 0 ]
	then 
		return
	fi
    
    do_gpt_partition ${RAIDDISK}
    PARTITION="${RAIDPARTITION}"
    
    echo "Creating filesystem on ${PARTITION}."
    mkfs -t ext4 ${PARTITION}
    mkdir "${MOUNTPOINT}"
    read UUID FS_TYPE < <(blkid -u filesystem ${PARTITION}|awk -F "[= ]" '{print $3" "$5}'|tr -d "\"")
    add_to_fstab "${UUID}" "${MOUNTPOINT}"
    echo "Mounting disk ${PARTITION} on ${MOUNTPOINT}"
    mount "${MOUNTPOINT}"
}

allow_passwordssh() {
	grep -q '^PasswordAuthentication yes' /etc/ssh/sshd_config
    if [ ${?} -eq 0 ];
    then
		return
	fi
    sed -i "s/^#PasswordAuthentication.*/PasswordAuthentication yes/I" /etc/ssh/sshd_config
    sed -i "s/^PasswordAuthentication no.*/PasswordAuthentication yes/I" /etc/ssh/sshd_config
	/etc/init.d/sshd reload
}

# temporary workaround form CRP 
allow_passwordssh  

check_os
if [ $iscentos -ne 0 ] && [ $isubuntu -ne 0 ];
then
    echo "unsupported operating system"
    exit 1 
else
    configure_disks
fi
