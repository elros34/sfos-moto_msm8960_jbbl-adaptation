#!/bin/bash
set -e
#set -x

# kill tracker junk unitl next boot
ln -s /dev/null /etc/systemd/user/tracker-extract.service
ln -s /dev/null /etc/systemd/user/tracker-miner-fs.service
ln -s /dev/null /etc/systemd/user/tracker-store.service
ln -s /dev/null /etc/systemd/user/tracker-writeback.service
systemctl-user daemon-reload 
systemctl-user stop tracker-extract.service tracker-miner-fs.service tracker-store.service tracker-writeback.service

PKG_DIR=/usr/share/sfos-moto_msm8960_jbbl-adaptation

echo -e "\n=== RELEASE: $RELEASE ===\n"
ssu release $RELEASE

# disable openrepos
OPENREPOS="$(ssu lr | sed -n '/Enabled repositories (user)/,/Disabled/p' | awk '/openrepos/{print $2}')"
echo -e "$OPENREPOS" > $PKG_DIR/.disabled_repos
for repo in $OPENREPOS; do
    ssu disablerepo $repo
done

patchmanager --unapply-all || true

ssu lr
zypper clean -a
zypper ref -f

echo -e "\n=== Available space in rootfs: ===\n"
df -h /
echo -e "\n=== Do you want to continue? [Y/n] ===\n"
read yn
if [ x$yn == x"n" ]; then
    exit 1
fi

version --dup
$PKG_DIR/moto_msm8960_jbbl.sh

for repo in $OPENREPOS; do
    ssu enablerepo $repo
done

rm -f /etc/systemd/user/{tracker-extract.service,tracker-miner-fs.service,tracker-store.service,tracker-writeback.service}

sync


