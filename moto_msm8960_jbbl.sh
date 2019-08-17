#!/bin/bash
set -e
#set -x

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
patch -p1 < jolla-camera.patch || true
cd -

# keyboard layout
echo "Overwritting hw keyboard layout!"
/bin/cp -rf $PKG_DIR/sparse/* /

# Enable zram
#ln -fs /lib/systemd/system/zramswap.service /lib/systemd/system/multi-user.target.wants/zramswap.service

add-oneshot --user --late update-mce-conf


