#!/bin/bash
set -e
set -x

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
echo "Adding http://repo.merproject.org/obs/home:/elros34:/sailfishapps/sailfishos_2.1.4.14/ repo"
ssu ar elros34-sailfishapps http://repo.merproject.org/obs/home:/elros34:/sailfishapps/sailfishos_2.1.4.14/

# Unlock screen on kbd slide 
mcetool --set-filter-lid-with-als=disabled
mcetool --set-kbd-slide-open-trigger=always
mcetool --set-kbd-slide-open-action=tkunlock
mcetool --set-kbd-slide-close-trigger=after-open
mcetool --set-kbd-slide-close-action=tklock

# Don't enable display when headphones are connected/disconnected or camera and volume buttons are pressed
mcetool --set-exception-length-jack-in=0
mcetool --set-exception-length-jack-out=0
mcetool --set-exception-length-camera=0
mcetool --set-exception-length-volume=0

