#!/bin/bash

# The only case where this script would fail is:
# mkfs.vfat /dev/mmcblk1 then repartitioning to create an empty ext2 partition

DEF_UID=$(grep "^UID_MIN" /etc/login.defs |  tr -s " " | cut -d " " -f2)
DEF_GID=$(grep "^GID_MIN" /etc/login.defs |  tr -s " " | cut -d " " -f2)
DEVICEUSER=$(getent passwd $DEF_UID | sed 's/:.*//')
MNT=/media/sdcard
MOUNT_OPTS="dirsync,noatime,users"
# options: --discard=once --priority 10
SWAP_OPTS="--discard --priority 10"
ACTION=$1
DEVNAME=$2

if [ -z "${ACTION}" ]; then
    systemd-cat -t mount-sd /bin/echo "ERROR: Action needs to be defined."
    exit 1
fi

if [ -z "${DEVNAME}" ]; then
    systemd-cat -t mount-sd /bin/echo "ERROR: Device name needs to be defined."
    exit 1
fi

systemd-cat -t mount-sd /bin/echo "Called to ${ACTION} ${DEVNAME}"

if [ "$ACTION" = "add" ]; then

    eval "$(/sbin/blkid -c /dev/null -o export /dev/$2)"

    if [ -z "${TYPE}" ]; then

        # In case filesystem type is missing, try reading it.
        TYPE=$(lsblk -n -o FSTYPE ${DEVNAME} | tail -n 1)

        if [ -z "${TYPE}" ]; then
            systemd-cat -t mount-sd /bin/echo "ERROR: Filesystem type missing for ${DEVNAME}."
            exit 1
    	fi
    fi

    if [ "${TYPE}" = "swap" ]; then
        SWAP=$(grep -w ${DEVNAME} /proc/swaps | cut -d \  -f 1)
        if [ -n "$SWAP" ]; then
            systemd-cat -t mount-sd /bin/echo "${DEVNAME} already used as swap space, ignoring"
            exit 0
        fi
        systemd-cat -t mount-sd /bin/echo "${DEVNAME} seems to be swap space"
        swapon $SWAP_OPTS ${DEVNAME}
        systemd-cat -t mount-sd /bin/echo "Finished ${ACTION}ing ${DEVNAME} of type ${TYPE} as swap space"
        exit 0
    fi

    if [ -z "${UUID}" ]; then
        # In case device does not have UUID lets create one for it based on
        # the card identification.
        PKNAME=$(lsblk -n -o PKNAME ${DEVNAME} | tail -n 1)

        # If there is no PKNAME try NAME instead.
        if [ -z "${PKNAME}" ]; then
            PKNAME=$(lsblk -n -o NAME ${DEVNAME} | head -n 1)
        fi

        if [ -e "/sys/block/${PKNAME}/device/cid" ]; then
            CID=$(cat /sys/block/${PKNAME}/device/cid)
            if [ -n "${CID}" ]; then
                IDNAME=$(lsblk -n -o NAME ${DEVNAME} | tail -1 | cut -d "-" -f2)
                UUID="${CID}-${IDNAME}"
            fi
        fi

        if [ -z "${UUID}" ]; then
            # Exit here as in the future there might be things like USB OTG disks or
            # sdcards attached via adapter that might behave differently and needs special case
            # in case such happens fail so we don't break anything.
            systemd-cat -t mount-sd /bin/echo "ERROR: Could not find or generate UUID for device ${DEVNAME}."
            exit 1
        fi
    fi

    DIR=$(grep -w ${DEVNAME} /proc/mounts | cut -d \  -f 2)
    if [ -n "$DIR" ]; then
        systemd-cat -t mount-sd /bin/echo "${DEVNAME} already mounted on ${DIR}, ignoring"
        exit 0
    fi

    case "${TYPE}" in
        f2fs)
            FSCK_OPTS="-a"
            ;;
        *)
            FSCK_OPTS="-p"
            ;;
    esac
    fsck $FSCK_OPTS ${DEVNAME}

    if [ "x${LABEL}" != "x" ]; then
        MNT_DIR="$MNT/${LABEL}"
		TMPNAME=$(grep -w ${MNT_DIR} /proc/mounts | cut -d \  -f 1)
        if [ -n "$TMPNAME" ]; then
            systemd-cat -t mount-sd /bin/echo "${TMPNAME} already mounted on ${MNT_DIR}, falling back to UUID"
            MNT_DIR="$MNT/${LABEL}"
            TMPNAME=$(grep -w ${MNT_DIR} /proc/mounts | cut -d \  -f 1)
            if [ -n "$TMPNAME" ]; then
                systemd-cat -t mount-sd /bin/echo "${TMPNAME} already mounted on ${MNT_DIR}, ignoring"
                exit 0
            fi
        fi
    else
        MNT_DIR="$MNT/${UUID}"
		TMPNAME=$(grep -w ${MNT_DIR} /proc/mounts | cut -d \  -f 1)
        if [ -n "$TMPNAME" ]; then
            systemd-cat -t mount-sd /bin/echo "${TMPNAME} already mounted on ${MNT_DIR}, ignoring"
            exit 0
        fi
    fi
    test -d $MNT_DIR || mkdir -p $MNT_DIR
    chown $DEF_UID:$DEF_GID $MNT $MNT_DIR
    touch $MNT_DIR

    case "${TYPE}" in
        vfat)
            MOUNT_OPTS+=",uid=$DEF_UID,gid=$DEF_GID,utf8,flush,discard"
            ;;
        exfat)
            MOUNT_OPTS+=",uid=$DEF_UID,gid=$DEF_GID,utf8,namecase=0,discard -t exfat"
            ;;
        # NTFS support has not been tested but it's being left to please the ego of an engineer!
        ntfs)
            MOUNT_OPTS+=",uid=$DEF_UID,gid=$DEF_GID,utf8"
            ;;
        # ext and btrfs are both able to handly TRIM. Add more to the list if needed.
        ext4|btrfs|f2fs)
            MOUNT_OPTS+=",discard"
            ;;
    esac
    mount ${DEVNAME} $MNT_DIR -o $MOUNT_OPTS || /bin/rmdir $MNT_DIR

    # This hack is here to delay indexing till the tracker has started.
    export DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/$DEF_UID/dbus/user_bus_socket
    count=1
    while true; do 
        test $count -ge 64 && break
        MINER_STATUS="$(dbus-send --type=method_call --print-reply --session --dest=org.freedesktop.Tracker1.Miner.Files /org/freedesktop/Tracker1/Miner/Files org.freedesktop.Tracker1.Miner.GetStatus | grep -o 'Idle')"
        STORE_STATUS="$(dbus-send --type=method_call --print-reply --session --dest=org.freedesktop.Tracker1 /org/freedesktop/Tracker1/Status org.freedesktop.Tracker1.Status.GetStatus | grep -o 'Idle')"
        test "$MINER_STATUS" = "Idle" -a "$STORE_STATUS" = "Idle" && break
        systemd-cat -t mount-sd /bin/echo "Waiting $count seconds for tracker"
        sleep $count ; 
        count=$(( count + count ))
    done
    test -d $MNT_DIR && touch $MNT_DIR

    systemd-cat -t mount-sd /bin/echo "Finished ${ACTION}ing ${DEVNAME} of type ${TYPE} at $MNT_DIR"

else
    DIR=$(grep -w ${DEVNAME} /proc/mounts | cut -d \  -f 2)
    if [ -n "${DIR}" ] ; then
        if [ "${DIR##$MNT}" = "${DIR}" ]; then
            systemd-cat -t mount-sd /bin/echo "${DEVNAME} mountpoint ${DIR} is not under ${MNT}, ignoring"
            exit 0
        fi
        umount $DIR || umount -l $DIR
        touch ${DIR} # Tell the tracker to reindex.
        rmdir ${DIR} || systemd-cat -t mount-sd /bin/echo "Warning: Can't remove directory ${DIR}" # Remove the temporary mount directory.
        systemd-cat -t mount-sd /bin/echo "Finished ${ACTION}ing ${DEVNAME} at ${DIR}"
    else
        SWAP=$(grep -w ${DEVNAME} /proc/swaps | cut -d \  -f 1)
        if [ -z "$SWAP" ]; then
            systemd-cat -t mount-sd /bin/echo "${DEVNAME} in not currently used as swap space, ignoring"
            exit 0
        fi
        swapoff "${SWAP}"
        systemd-cat -t mount-sd /bin/echo "Finished ${ACTION}ing ${DEVNAME} as swap space"
    fi
fi

