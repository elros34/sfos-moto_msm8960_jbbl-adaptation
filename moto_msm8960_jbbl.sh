#!/bin/bash
set -e
set -x

# system mount
echo "Removing remount option from system.mount"
sed -i "s|Options=ro,remount|Options=ro|" /lib/systemd/system/system.mount

# camera 
echo "Patching jolla-camera"
/bin/cp -f /usr/share/sfos-moto_msm8960_jbbl-adaptation/patches/jolla-camera.patch /usr/lib/qt5/qml/com/jolla/camera/capture/
cd /usr/lib/qt5/qml/com/jolla/camera/capture/
patch -p1 < jolla-camera.patch
cd -

# APN settings
echo "Changing /var/lib/ofono ownership"
chown -R radio:radio /var/lib/ofono

# Make sure system partition is mounted before droid-hal-init
cat << EOF >> /lib/systemd/system/local-fs.target

[Install]
RequiredBy=droid-hal-init.service
EOF

sed -i "s|WantedBy=local-fs.target|RequiredBy=local-fs.target|g" /lib/systemd/system/system.mount

# Delay sensorfwd start
sed -i "s|After=dbus.socket|After=dbus.socket sys-devices-platform-SENSOR.3.device\nRequires=sys-devices-platform-SENSOR.3.device|g" /lib/systemd/system/sensorfwd.service

# keyboard layout, mount-sd.sh
/bin/cp -rf /usr/share/sfos-moto_msm8960_jbbl-adaptation/sparse/* /

# Enable zram
#ln -fs /lib/systemd/system/zramswap.service /lib/systemd/system/multi-user.target.wants/zramswap.service

# Add repo used in image creation with modified fingerterm, warehouse and sdcard-moded
echo "Adding http://repo.merproject.org/obs/home:/elros34:/sailfishapps/sailfishos_2.1.3.7/ repo"
ssu ar elros34-sailfishapps http://repo.merproject.org/obs/home:/elros34:/sailfishapps/sailfishos_2.1.3.7/
