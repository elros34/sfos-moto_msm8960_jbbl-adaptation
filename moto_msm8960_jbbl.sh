#!/bin/bash
set -e
set -x

if [ x$1 != "xmic" ] && [ "$(evdev_trace -i 1 | grep Name | cut -d"\"" -f2)" != "keypad_8960" ]; then
	echo "It's not Photon Q !"
	exit 1
fi

if [ $(whoami) != "root" ]; then 
	echo "I need root power!"
	exit 1
fi

PKG_DIR="/usr/share/sfos-moto_msm8960_jbbl-adaptation"

mkdir -p $PKG_DIR/backup/

# system mount
echo "Removing remount option from system.mount"
/bin/cp -f /lib/systemd/system/system.mount $PKG_DIR/backup/
sed -i "s|Options=ro,remount|Options=ro|" /lib/systemd/system/system.mount

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
cat << EOF >> /lib/systemd/system/local-fs.target

[Install]
RequiredBy=droid-hal-init.service
EOF

sed -i "s|WantedBy=local-fs.target|RequiredBy=local-fs.target|g" /lib/systemd/system/system.mount

# keyboard layout, mount-sd.sh
/bin/cp -rf /usr/share/sfos-moto_msm8960_jbbl-adaptation/sparse/* /

# Enable zram
#ln -fs /lib/systemd/system/zramswap.service /lib/systemd/system/multi-user.target.wants/zramswap.service

# Add repo used in image creation with modified fingerterm, warehouse and sdcard-moded
echo "Adding http://repo.merproject.org/obs/home:/elros34:/sailfishapps/sailfishos_2.2.0.29/ repo"
ssu ar elros34-sailfishapps http://repo.merproject.org/obs/home:/elros34:/sailfishapps/sailfishos_2.2.0.29/

add-oneshot --user --late update-mce-conf

