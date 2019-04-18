#!/bin/bash
set -x
set -e

if [ $(whoami) != "root" ]; then 
	echo "I need root power!"
	exit 1
fi

PKG_DIR=/usr/share/sfos-moto_msm8960_jbbl-adaptation
RELEASE="$(curl http://repo.merproject.org/obs/nemo:/testing:/hw:/motorola:/moto_msm8960_jbbl/ 2>/dev/null | pcregrep -o1 '\"sailfishos_([\d\.]+)' | tail -n1)"

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

pkcon refresh
sync


