#!/bin/bash
set -e
#set -x

if [ $(whoami) != "root" ]; then 
	echo "I need root power!"
	exit 1
fi


export CURRENT_RELEASE="$(ssu re | pcregrep -o1 '([\d\.]+)')" 

if [ $# -ge 1 ]; then
    if [[ "$1" == "--local="* ]]; then
        export NEXT_RELEASE="$(cut -d= -f2 <<< $1)"
        createrepo_c --update /droid-local-repo
        ssu ar droid-local-repo file:///droid-local-repo
        zypper ref droid-local-repo
        zypper --non-interactive in --force --from droid-local-repo sfos-moto_msm8960_jbbl-adaptation

        /usr/share/sfos-moto_msm8960_jbbl-adaptation/real-upgrade.sh
    
        #ssu rr droid-local-repo
        exit 0
    else
        echo "Incorrect argument" 
        exit 1
    fi
fi


release2num() {
    echo "$1" | awk -v FS=. '{print $1$2$3}'
}

# 1.0.2.5, 1.1.2.16, 1.1.7.28, 1.1.9.30, 2.0.0.10, 2.2.0.29, 3.0.0.8, 3.2.0.12
# Stop releases without minor
# cloudfire blocks it..
#STOP_RELEASES="$(curl https://jolla.zendesk.com/hc/en-us/articles/201836347 2>/dev/null | pcregrep -o1 '<li>(\d\.\d\.\d).*</li>')"
STOP_RELEASES="1.0.2 1.1.2 1.1.7 1.1.9 2.0.0 2.2.0 3.0.0 3.2.0"
AVAILABLE_RELEASES="$(curl http://repo.merproject.org/obs/nemo:/testing:/hw:/motorola:/moto_msm8960_jbbl/ 2>/dev/null | pcregrep -o1 '\"sailfishos_([\d\.]+)')"
CURRENT_RELEASE_NUM="$(release2num $CURRENT_RELEASE)"
NEXT_RELEASE="$(echo $AVAILABLE_RELEASES  | tr ' ' '\n' | tail -n1)"

# Found next stop release
for r in $STOP_RELEASES; do 
    nr="$(release2num $r)"
    if [ $CURRENT_RELEASE_NUM -lt $nr ]; then
        NEXT_RELEASE="$(echo $AVAILABLE_RELEASES  | tr ' ' '\n' | grep $r)"
        echo "Found next release: $NEXT_RELEASE"
        break
    fi
done

if [ -z "$NEXT_RELEASE" ]; then
    echo "Can't find next release" 
    exit 1
fi

if [ "$NEXT_RELEASE" == "$CURRENT_RELEASE" ]; then
    echo "Can't find newer release than $CURRENT_RELEASE"   
    exit 1
fi

# Download latest package
ssu ar hw_repo_tmp "http://repo.merproject.org/obs/nemo:/testing:/hw:/motorola:/moto_msm8960_jbbl/sailfishos_$NEXT_RELEASE/"
zypper ref hw_repo_tmp
zypper --non-interactive in --force --from hw_repo_tmp sfos-moto_msm8960_jbbl-adaptation
ssu rr hw_repo_tmp

export NEXT_RELEASE
/usr/share/sfos-moto_msm8960_jbbl-adaptation/real-upgrade.sh

