#!/bin/bash
set -e
set -x

if [ $(whoami) != "root" ]; then 
	echo "I need root power!"
	exit 1
fi

PKG_DIR="/usr/share/sfos-moto_msm8960_jbbl-adaptation"

mkdir -p $PKG_DIR/backup/

# camera 
echo "Patching jolla-camera"
CAMERA_DIR="/usr/lib/qt5/qml/com/jolla/camera/capture"
/bin/cp -f $CAMERA_DIR/CaptureOverlay.qml $PKG_DIR/backup/
/bin/cp -f $CAMERA_DIR/CaptureView.qml $PKG_DIR/backup/

/bin/cp -f $PKG_DIR/patches/jolla-camera.patch $CAMERA_DIR
cd $CAMERA_DIR
patch -p1 < jolla-camera.patch
cd -

# APN settings
if [ "$(ls -ld /var/lib/ofono | cut -d" " -f3,4)" != "radio radio" ]; then
	echo "Changing /var/lib/ofono ownership"
	chown -R radio:radio /var/lib/ofono
fi

# Make sure system partition is mounted before droid-hal-init
/bin/cp -f /lib/systemd/system/local-fs.target $PKG_DIR/backup/
cat <<EOF >> /lib/systemd/system/local-fs.target

[Install]
RequiredBy=droid-hal-init.service
EOF

sed -i "s|WantedBy=local-fs.target|RequiredBy=local-fs.target|g" /lib/systemd/system/system.mount

# keyboard layout
/bin/cp -rf $PKG_DIR/sparse/* /

# Enable zram
#ln -fs /lib/systemd/system/zramswap.service /lib/systemd/system/multi-user.target.wants/zramswap.service

add-oneshot --user --late update-mce-conf

if [ x$1 == x"mic" ]; then
    echo "Run in mic"  
else
    $PKG_DIR/amend_device.sh "$(getprop ro.product.device)"
fi

