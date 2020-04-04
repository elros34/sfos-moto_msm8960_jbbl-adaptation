#!/bin/bash
set -e
#set -x

# upgrade quirks
if [ "$NEXT_RELEASE" == "3.3.0.16" ] && [ -f "/usr/sbin/collectd" ]; then
    COLLECTD_VERSION="$(zypper info collectd | awk '/Version/ {printf $3}')"
    echo -e "\n=== collectd=$COLLECTD_VERSION installed, it may cause issues during upgrade. More info at TJC. Do you want to remove it? [Y/n] ===\n"
    read yn
    [ "$yn" != "n" ] && zypper --non-interactive remove collectd
fi

# Delete previous update files
rm -rf /home/.pk-zypp-dist-upgrade-cache/*
rm -f /home/nemo/.cache/sailfish-osupdateservice/os-info

# kill tracker junk unitl next boot
ln -sf /dev/null /etc/systemd/user/tracker-extract.service
ln -sf /dev/null /etc/systemd/user/tracker-miner-fs.service
ln -sf /dev/null /etc/systemd/user/tracker-store.service
ln -sf /dev/null /etc/systemd/user/tracker-writeback.service
systemctl-user daemon-reload 
systemctl-user stop tracker-extract.service tracker-miner-fs.service tracker-store.service tracker-writeback.service

PKG_DIR=/usr/share/sfos-moto_msm8960_jbbl-adaptation

echo -e "\n=== Do you want to upgrade from $CURRENT_RELEASE to $NEXT_RELEASE? [Y/n] ===\n"
read yn
[ "$yn" == "n" ] && exit 1
ssu release $NEXT_RELEASE

echo -e "\n=== Available space in rootfs: ===\n"
df -h /
echo -e "\n=== Do you want to continue? [Y/n] ===\n"
read yn
[ "$yn" == "n" ] && exit 1

ssu updaterepos

# disable openrepos
OPENREPOS="$(ssu lr | sed -n '/Enabled repositories (user)/,/Disabled/p' | awk '/openrepos/{print $2}')"
echo -e "$OPENREPOS" > $PKG_DIR/.disabled_repos
for repo in $OPENREPOS; do
    ssu disablerepo $repo
done

[ -x /usr/sbin/patchmanager ] && patchmanager --unapply-all || true

ssu lr
echo -e "\n=== Make sure all repos are correct. Do you want to upgrade your system? [Y/n]  ===\n"
read yn
[ "$yn" == "n" ] && exit 1

zypper clean -a
zypper ref -f

version --dup
$PKG_DIR/moto_msm8960_jbbl.sh

for repo in $OPENREPOS; do
    ssu enablerepo $repo
done

rm -f /etc/systemd/user/{tracker-extract.service,tracker-miner-fs.service,tracker-store.service,tracker-writeback.service}

sync


