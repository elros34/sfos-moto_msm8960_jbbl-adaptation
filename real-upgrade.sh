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

enableDisabledRepos() {
    [ ! -f "$PKG_DIR/.disabled_repos" ] && return 0
    USERREPOS="$(cat $PKG_DIR/.disabled_repos)"
    echo -e "\n=== Enabling previously disabled repositories ===\n"
    for repo in $USERREPOS; do
        ssu enablerepo $repo
    done
    /bin/rm -f $PKG_DIR/.disabled_repos || true
}

# upgrade quirks

if [[ "$NEXT_RELEASE" == "4.4.0"* ]]; then
    # add new repo url
    ssu addrepo hw_repo_tmp "https://repo.sailfishos.org/obs/nemo:/testing:/hw:/motorola:/moto_msm8960_jbbl:/4.4.0.68/sailfishos/"
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
        ! mountpoint -q /home/.pk-zypp-dist-upgrade-cache/ && mount --rbind --make-rslave /cache/.pk-zypp-dist-upgrade-cache /home/.pk-zypp-dist-upgrade-cache/
    fi
fi

# kill tracker junk unitl next boot
ln -sf /dev/null /etc/systemd/user/tracker-extract.service
ln -sf /dev/null /etc/systemd/user/tracker-miner-fs.service
ln -sf /dev/null /etc/systemd/user/tracker-store.service
ln -sf /dev/null /etc/systemd/user/tracker-writeback.service
systemctl-user daemon-reload 
systemctl-user stop tracker-extract.service tracker-miner-fs.service tracker-store.service tracker-writeback.service

echo -e "\n=== Available space in rootfs: $(df -h / | awk '/\// {print $4}') ===\n"
if [ "$use_cache_part" == "yes" ]; then
    echo -e "\n=== Installation requires at least 500MB (1GB to be safe) ===\n"
else
    echo -e "\n=== Installation requires at least 800MB (1GB to be safe) ===\n"
fi
echo -e "\n=== Do you want to upgrade from $CURRENT_RELEASE to $NEXT_RELEASE? [Y/n] ===\n"
read yn
[[ "$yn" == [nN] ]] && exit 1

ssu release $NEXT_RELEASE
# ssu bug: https://forum.sailfishos.org/t/ssu-features-are-not-updated-on-removal-of-the-settings-files/7364
rm -rf /var/cache/ssu || true
ssu updaterepos

# disable some user repos
echo -e "\n=== Disabling some user repositories ===\n"
USERREPOS="$(ssu lr | sed -n '/Enabled repositories (user)/,/Disabled/p' | awk '/openrepos/ || /sailfishos-chum/{print $2}')"
echo -e "$USERREPOS" > $PKG_DIR/.disabled_repos
for repo in $USERREPOS; do
    ssu disablerepo $repo
done

echo -e "\n=== Make sure all repos are correct because 'zypper' will not really check it!  ===\n"
sleep 3
ssu lr
reposUrls="$(ssu lr | sed -n '/Enabled repositories/,/Disabled repositories/p' | awk '/ - /{print $2"@"$4}')"
for data in $reposUrls; do
    repoName="$(cut -d"@" -f1 <<< $data)"
    repoUrl="$(cut -d"@" -f2 <<< $data)"
    # jolla store requires authorisation
    [ "$repoName" == "store" ] && continue
    httpCode="$(curl --silent --head --location --output /dev/null --write-out '%{http_code}' ${repoUrl}/repodata/repomd.xml)"
    if [ "$httpCode" == "200" ]; then
        echo -e "=== \"$repoName\": is available ===\n"
    else
        echo -e "=== \"$repoName\": is invalid! ==="
        echo -e "${repoUrl}/repodata/repomd.xml: $httpCode\n"
    fi
done

echo -e "\n=== Do you want to upgrade your system? [Y/n]  ===\n"
read yn
[[ "$yn" == [nN] ]] && enableDisabledRepos && exit 1

echo -e "\n=== Disabling patches  ===\n"
[ -x /usr/sbin/patchmanager ] && patchmanager --unapply-all || true

zypper clean -a
zypper ref -f
echo -e "\n=== Show upgrade details? [y/N] ===\n"
read yn
[[ "$yn" == [yY] ]] && zypper dup --details || zypper dup || true
#version --dup

[[ "$NEXT_RELEASE" == "3.4.0"* ]] && zypper --non-interactive in --force patterns-sailfish-device-configuration-moto_msm8960_jbbl

# Looks like browser changed app data location but there is no code/script which will move bookmarks.json and sailfish-browser.sqlite to new location: https://forum.sailfishos.org/t/4-0-1-48-lost-bookmarks-of-the-sailfish-webbrowser-after-the-update/5009
if [[ "$NEXT_RELEASE" == "4.0.1"* ]]; then
    echo -e "\n=== Browser data transition is required because jolla forgot about it! Think twice if mv command ask you to overwrite files. ===\n"
    /bin/mv -i /home/nemo/.local/share/org.sailfishos/sailfish-browser/{bookmarks.json,sailfish-browser.sqlite} /home/nemo/.local/share/org.sailfishos/browser/ || true
fi

if [[ "$NEXT_RELEASE" == "4.4.0"* ]]; then
    ssu removerepo hw_repo_tmp
fi

enableDisabledRepos

rm -f /etc/systemd/user/{tracker-extract.service,tracker-miner-fs.service,tracker-store.service,tracker-writeback.service}
rm -rf /home/.pk-zypp-dist-upgrade-cache/{solv,raw,packages}
mountpoint -q /home/.pk-zypp-dist-upgrade-cache/ && umount /home/.pk-zypp-dist-upgrade-cache || true

rm -rf /var/cache/ssu || true
ssu updaterepos
zypper ref

sync
echo -e "\n=== Upgrade to $NEXT_RELEASE finished ===\n"

