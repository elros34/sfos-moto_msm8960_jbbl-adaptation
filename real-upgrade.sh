#!/bin/bash
set -e
#set -x

PKG_DIR=/usr/share/sfos-moto_msm8960_jbbl-adaptation

removePKG() {
    PKG="$1"
    VERSION="$(zypper info $PKG | awk '/Version/ {printf $3}')"
    echo -e "\n=== $PKG=$VERSION installed, it may cause issues during upgrade. More info at TJC or forum.sailfishos.org. Do you want to remove it? [Y/n] ===\n"
    read yn
    [[ "$yn" != [nN] ]] && zypper --non-interactive remove $PKG
}

# upgrade quirks
if [ "$NEXT_RELEASE" == "3.3.0.16" ]; then
    [ -f "/usr/sbin/collectd" ] && removePKG "collectd"
fi

if [[ "$NEXT_RELEASE" == "3.4.0"* ]]; then
    gpasswd -d nemo system || true
    
    # overlay apps
    [ -f "/usr/bin/phonehook" ] && removePKG "phonehook"
    [ -f "/usr/bin/harbour-batteryoverlay2" ] && removePKG "harbour-batteryoverlay2"
    [ -f "/usr/bin/harbour-tint-overlay" ] && removePKG "harbour-tint-overlay"
    [ -f "/usr/bin/harbour-taskswitcher" ] && removePKG "harbour-taskswitcher"
    [ -f "/usr/bin/harbour-screentapshot2" ] && removePKG "harbour-screentapshot2"
fi

# sys-fs-pstore leftover
rm -f /etc/systemd/system/local-fs.target.wants/sys-fs-pstore.mount

# Delete files from previous update
rm -rf /home/.pk-zypp-dist-upgrade-cache/*
rm -f /home/nemo/.cache/sailfish-osupdateservice/os-info

# kill tracker junk unitl next boot
ln -sf /dev/null /etc/systemd/user/tracker-extract.service
ln -sf /dev/null /etc/systemd/user/tracker-miner-fs.service
ln -sf /dev/null /etc/systemd/user/tracker-store.service
ln -sf /dev/null /etc/systemd/user/tracker-writeback.service
systemctl-user daemon-reload 
systemctl-user stop tracker-extract.service tracker-miner-fs.service tracker-store.service tracker-writeback.service

echo -e "\n=== Available space in rootfs: ===\n"
df -h /
echo -e "\n=== Requires at least 800MB (1GB to be safe) ===\n"
echo -e "\n=== Do you want to upgrade from $CURRENT_RELEASE to $NEXT_RELEASE? [Y/n] ===\n"
read yn
[[ "$yn" == [nN] ]] && exit 1

ssu release $NEXT_RELEASE
ssu updaterepos

# disable openrepos
echo -e "\n=== Disabling openrepos ===\n"
OPENREPOS="$(ssu lr | sed -n '/Enabled repositories (user)/,/Disabled/p' | awk '/openrepos/{print $2}')"
echo -e "$OPENREPOS" > $PKG_DIR/.disabled_repos
for repo in $OPENREPOS; do
    ssu disablerepo $repo
done

echo -e "\n=== Disabling patches  ===\n"
[ -x /usr/sbin/patchmanager ] && patchmanager --unapply-all || true

ssu lr
echo -e "\n=== Make sure all repos are correct. Do you want to upgrade your system? [Y/n]  ===\n"
read yn
[[ "$yn" == [nN] ]] && exit 1

zypper clean -a
zypper ref -f

version --dup
[[ "$NEXT_RELEASE" == "3.4.0"* ]] && zypper --non-interactive in --force patterns-sailfish-device-configuration-moto_msm8960_jbbl
$PKG_DIR/moto_msm8960_jbbl.sh

echo -e "\n=== Enabling openrepos ===\n"
for repo in $OPENREPOS; do
    ssu enablerepo $repo
done

rm -f /etc/systemd/user/{tracker-extract.service,tracker-miner-fs.service,tracker-store.service,tracker-writeback.service}

sync


