#!/bin/bash
set -e
#set -x

if [ $(whoami) != "root" ]; then 
	echo "I need root power!"
	exit 1
fi

release2num() {
    echo "$1" | awk -v FS=. '{print $1$2$3}'
}

# Stop releases without minor
# 1.0.2.5, 1.1.2.16, 1.1.7.28, 1.1.9.30, 2.0.0.10, 2.2.0.29, 3.0.0.8, 3.2.0.12
STOP_RELEASES="$(curl https://jolla.zendesk.com/hc/en-us/articles/201836347 2>/dev/null | pcregrep -o1 "<li>(\d\.\d\.\d).*</li>")"
CURRENT_RELEASE="$(ssu re | pcregrep -o1 "((\d\.)+\d+)")"
AVAILABLE_RELEASES="$(curl http://repo.merproject.org/obs/nemo:/testing:/hw:/motorola:/moto_msm8960_jbbl/ 2>/dev/null | pcregrep -o1 '\"sailfishos_([\d\.]+)')"
NUM_CURRENT_RELEASE="$(release2num $CURRENT_RELEASE)"
RELEASE="$(echo $AVAILABLE_RELEASES  | tr ' ' '\n' | tail -n1)"

# Found next stop release
for r in $STOP_RELEASES; do 
    nr="$(release2num $r)"
    if [ $NUM_CURRENT_RELEASE -lt $nr ]; then
        RELEASE="$(echo $AVAILABLE_RELEASES  | tr ' ' '\n' | grep $r)"
        echo "Found next release: $RELEASE"
        break
    fi
done

if [ -z "$RELEASE" ]; then
    echo "Can't find newer release then $CURRENT_RELEASE"   
    exit 1
fi

# Download latest package
ssu ar hw_repo_tmp "http://repo.merproject.org/obs/nemo:/testing:/hw:/motorola:/moto_msm8960_jbbl/sailfishos_$RELEASE/armv7hl/"
zypper ref hw_repo_tmp
zypper in --force --from hw_repo_tmp sfos-moto_msm8960_jbbl-adaptation
ssu rr hw_repo_tmp

export $RELEASE
/usr/share/sfos-moto_msm8960_jbbl-adaptation/real-upgrade.sh

