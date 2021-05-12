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

# Stop Releases without minor part
# cloudfire blocks it..
#STOP_RELEASES="$(curl https://jolla.zendesk.com/hc/en-us/articles/201836347 2>/dev/null | pcregrep -o1 '<li>(\d\.\d\.\d).*</li>')"
STOP_RELEASES="1.0.2 1.1.2 1.1.7 1.1.9 2.0.0 2.2.0 3.0.0 3.2.0 3.4.0 4.0.1"
AVAILABLE_RELEASES="$(curl http://repo.merproject.org/obs/nemo:/testing:/hw:/motorola:/moto_msm8960_jbbl/ 2>/dev/null | pcregrep -o1 '\"sailfishos_([\d\.]+)')"
CURRENT_RELEASE_NUM="$(release2num $CURRENT_RELEASE)"
NEXT_RELEASE="$CURRENT_RELEASE"

# Found next Stop Release
for r in $STOP_RELEASES; do 
    nr="$(release2num $r)"
    if [ $nr -gt $CURRENT_RELEASE_NUM ]; then
        NEXT_RELEASE="$(echo $AVAILABLE_RELEASES  | tr ' ' '\n' | grep $r)"
        break
    fi
done

if [ -z "$NEXT_RELEASE" ]; then
    # Set next release if next Stop Release could not be found
    for r in $AVAILABLE_RELEASES; do
        nr="$(release2num $r)"
        if [ $nr -gt $CURRENT_RELEASE_NUM ]; then
            NEXT_RELEASE=$r
            break
        fi
    done
fi

echo "Next release: $NEXT_RELEASE"

if [ "$NEXT_RELEASE" == "$CURRENT_RELEASE" ]; then
    echo "Can't find newer release than $CURRENT_RELEASE"   
    echo "Do you want to upgrade packages in current release anyway (not recommended)? [y/N]"
    read yn
    [[ "$yn" != [yY] ]] && exit 1
fi

# Download latest package
ssu ar hw_repo_tmp "http://repo.merproject.org/obs/nemo:/testing:/hw:/motorola:/moto_msm8960_jbbl/sailfishos_$NEXT_RELEASE/"
zypper ref hw_repo_tmp
zypper --non-interactive in --force --from hw_repo_tmp sfos-moto_msm8960_jbbl-adaptation
ssu rr hw_repo_tmp

export NEXT_RELEASE
/usr/share/sfos-moto_msm8960_jbbl-adaptation/real-upgrade.sh

