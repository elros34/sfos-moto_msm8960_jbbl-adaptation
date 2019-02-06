#!/bin/bash
set -x
set -e

if [ $(whoami) != "root" ]; then 
	echo "I need root power!"
	exit 1
fi

amend_paritions() {
    INITRAMFS_CPIO="boot-initramfs"
    INITRAMFS_GZ="$INITRAMFS_CPIO.gz"

    # unpack initramfs and fix init script
    zypper in --force -y droid-hal-moto_msm8960_jbbl-kernel
    mkdir -p /boot/initramfs-root
    cd /boot/initramfs-root
    mv /boot/$INITRAMFS_GZ /boot/initramfs-root/
    gunzip $INITRAMFS_GZ  
    cpio --null -iv < $INITRAMFS_CPIO
    sed -i 's!mmcblk0p39!mmcblk0p38!' init

    # create new hybris-boot
    rm $INITRAMFS_CPIO
    rm ../$INITRAMFS_GZ
    find . -print0 | cpio --null --format='newc' -ov > ../$INITRAMFS_CPIO
    gzip -9 ../$INITRAMFS_CPIO
    cd ..

    KERNEL="$(rpm -ql droid-hal-moto_msm8960_jbbl-kernel | grep kernel)"
    mkbootimg --cmdline 'console=/dev/null androidboot.hardware=qcom user_debug=31 loglevel=1 zcache=lz4 androidboot.selinux=permissive selinux=0 audit=0' --kernel $KERNEL --ramdisk $INITRAMFS_GZ --base 0x00000000 --pagesize 2048 --kernel_offset 0x80208000 --ramdisk_offset 0x81800000 --second_offset 0x81100000 --tags_offset 0x80200100 -o hybris-boot-$1.img

    /usr/sbin/flash-partition boot /boot/hybris-boot-$1.img

    # clean up
    rm /boot/hybris-boot-$1.img
    rm -fr /boot/initramfs-root

    # fix systemd *.mount
    sed -i 's!mmcblk0p37!mmcblk0p36!' /lib/systemd/system/system.mount
}

if [ x$1 == x"xt897" ] || [ x$1 == x"asanti_c" ] || [[ x$1 == x"photon"*"q" ]]; then
    echo "photon q"
elif [ x$1 == x"xt925" ] || [ x$1 == x"xt926" ] || [[ x$1 == x"razr"*"hd" ]]; then
    amend_paritions "xt925"
elif [ x$1 == x"xt907" ] || [[ x$1 == x"droid"*"razr"*"m" ]]; then
    amend_paritions "xt907"
fi


