#!/bin/bash
set -e
#set -x

if [ $(whoami) != "root" ]; then 
	echo "I need root power!"
	exit 1
fi

export RELEASE="$(curl http://repo.merproject.org/obs/nemo:/testing:/hw:/motorola:/moto_msm8960_jbbl/ 2>/dev/null | pcregrep -o1 '\"sailfishos_([\d\.]+)' | tail -n1)"

# Download latest package
ssu ar hw_repo_tmp "http://repo.merproject.org/obs/nemo:/testing:/hw:/motorola:/moto_msm8960_jbbl/sailfishos_$RELEASE/armv7hl/"
zypper ref hw_repo_tmp
zypper in --from hw_repo_tmp sfos-moto_msm8960_jbbl-adaptation
ssu rr hw_repo_tmp

/usr/share/sfos-moto_msm8960_jbbl-adaptation/real-upgrade.sh

