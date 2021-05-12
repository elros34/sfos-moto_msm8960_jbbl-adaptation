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

if [[ "$NEXT_RELEASE" == "3.4.0"* ]]; then
    gpasswd -d nemo system || true
    
    # overlay apps
    which "phonehook" && removePKG "phonehook"
    which "harbour-batteryoverlay2" && removePKG "harbour-batteryoverlay2"
    which "harbour-tint-overlay" && removePKG "harbour-tint-overlay"
    which "harbour-taskswitcher" && removePKG "harbour-taskswitcher"
    which "harbour-screentapshot2" && removePKG "harbour-screentapshot2"
fi

# droid-hal doesn't remove mount units symlinks on upgrade
rm -f /etc/systemd/system/local-fs.target.wants/sys-fs-pstore.mount

# Delete files from previous update
# https://jolla.zendesk.com/hc/en-us/articles/360005795474-Installing-an-OS-update-fails-download-worked-
rm -rf /home/.pk-zypp-dist-upgrade-cache/*
rm -f /home/nemo/.cache/sailfish-osupdateservice/os-info

# try to use /cache partition for rpms
use_cache_part="no"
rm -rf /cache/.pk-zypp-dist-upgrade-cache/{solv,raw,packages}
part_info=$(df -h /cache | grep '/dev/')
if [ "$(awk '/dev/ {print $6}' <<< $part_info)" == "/cache" ]; then
    echo -e "\n=== $(awk '/dev/ {print $4}' <<< $part_info) available at /cache ===\n"
    echo -e "\n=== Do you want to use /cache for rpm download storage? [y/N] ===\n"
    read yn
    if [[ "$yn" == [yY] ]]; then
        use_cache_part="yes"
        pkill store-client || true
        mkdir -p /cache/.pk-zypp-dist-upgrade-cache
        mount --rbind --make-rslave /cache/.pk-zypp-dist-upgrade-cache /home/.pk-zypp-dist-upgrade-cache/
    fi
fi

# kill tracker junk unitl next boot
ln -sf /dev/null /etc/systemd/user/tracker-extract.service
ln -sf /dev/null /etc/systemd/user/tracker-miner-fs.service
ln -sf /dev/null /etc/systemd/user/tracker-store.service
ln -sf /dev/null /etc/systemd/user/tracker-writeback.service
systemctl-user daemon-reload 
systemctl-user stop tracker-extract.service tracker-miner-fs.service tracker-store.service tracker-writeback.service

echo -e "\n=== Available space in rootfs: $(df -h / | awk '/rootfs/ {print $4}') ===\n"
if [ "$use_cache_part" == "yes" ]; then
    echo -e "\n=== Installation requires at least 500MB (1GB to be safe) ===\n"
else
    echo -e "\n=== Installation requires at least 800MB (1GB to be safe) ===\n"
fi
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

# Looks like browser changed app data location but there is no code/script which will move bookmarks.json and sailfish-browser.sqlite to new location: https://forum.sailfishos.org/t/4-0-1-48-lost-bookmarks-of-the-sailfish-webbrowser-after-the-update/5009
[[ "$NEXT_RELEASE" == "4.0.1"* ]] && /bin/cp -af --backup=numbered /home/nemo/.local/share/org.sailfishos/sailfish-browser/* /home/nemo/.local/share/org.sailfishos/browser/

echo -e "\n=== Enabling openrepos ===\n"
for repo in $OPENREPOS; do
    ssu enablerepo $repo
done

rm -f /etc/systemd/user/{tracker-extract.service,tracker-miner-fs.service,tracker-store.service,tracker-writeback.service}
rm -rf /home/.pk-zypp-dist-upgrade-cache/{solv,raw,packages}

sync
echo -e "\n=== Upgrade to $NEXT_RELEASE finished ===\n"

