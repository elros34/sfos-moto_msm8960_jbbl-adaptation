#!/bin/bash
set -e

if [ $(whoami) != "root" ]; then 
	echo "I need root power!"
	exit 1
fi

SCRIPT_PATH="$0"
STAGE="1"
debug_mode="0"

export CURRENT_RELEASE="$(ssu re | pcregrep -o1 '([\d\.]+)')" 

while [ $# -gt 0 ]; do
    case $1 in
        "--local")
            shift
            export NEXT_RELEASE="$1"
            createrepo_c --update /droid-local-repo
            ssu ar droid-local-repo file:///droid-local-repo
            zypper ref droid-local-repo
            zypper --non-interactive in --force --from droid-local-repo sfos-moto_msm8960_jbbl-adaptation

            /usr/share/sfos-moto_msm8960_jbbl-adaptation/real-upgrade.sh
    
            #ssu rr droid-local-repo
            exit 0
            ;;
        "--second")
            STAGE="2"
            echo "Second stage"
            shift
            ;;
        "--debug")
            echo "Debug mode"
            set -x
            export debug_mode="1"
            shift
            ;;
        *)
            echo -e "Usage: upgrade.sh [options]\n" \
                    "Options:\n" \
                    "  --local <release number>     Upgrade from /droid-local-repo directory.\n"
                    "  --debug                      Debug mode\n"
            exit 1
            ;;
    esac
done

release2num() {
    echo "$1" | awk -v FS=. '{print $1$2$3}'
}

# Stop Releases without minor part
# cloudfire blocks it..
# STOP_RELEASES="$(curl https://jolla.zendesk.com/hc/en-us/articles/201836347 2>/dev/null | pcregrep -o1 '<li>(\d\.\d\.\d).*</li>')"
# New same not up-to-date source for Stop Releases: https://raw.githubusercontent.com/sailfishos/docs.sailfishos.org/master/Releases/README.md
# STOP_RELEASES="$(curl https://jolla.zendesk.com/hc/en-us/articles/201836347 2>/dev/null | pcregrep -o1 '\| (\d\.\d\.\d).*\*\*Stop release\*\*')"
STOP_RELEASES="1.0.2 1.1.2 1.1.7 1.1.9 2.0.0 2.2.0 3.0.0 3.2.0 3.4.0 4.0.1 4.1.0 4.2.0 4.3.0 4.4.0"
CURRENT_RELEASE_NUM="$(release2num $CURRENT_RELEASE)"
if [ "$CURRENT_RELEASE_NUM" -ge 430 ]; then
    # There are some 4.4.0.58 leftovers on obs, TODO: fixme for next problematic releases
    AVAILABLE_RELEASES="$(curl http://repo.sailfishos.org/obs/nemo:/testing:/hw:/motorola:/moto_msm8960_jbbl:/ 2>/dev/null | pcregrep -o1 '\"(\d\.\d\.\d\.\d+)')"
else
    AVAILABLE_RELEASES="$(curl http://repo.merproject.org/obs/nemo:/testing:/hw:/motorola:/moto_msm8960_jbbl/ 2>/dev/null | pcregrep -o1 '\"sailfishos_([\d\.]+)')"
fi
NEXT_RELEASE="$CURRENT_RELEASE"

# Found next Stop Release
for r in $STOP_RELEASES; do
    nr="$(release2num $r)"
    if [ $nr -gt $CURRENT_RELEASE_NUM ]; then
        NEXT_RELEASE="$(echo $AVAILABLE_RELEASES  | tr ' ' '\n' | grep $r | tail -n1 || true)"
        break
    fi
done

if [ -z "$NEXT_RELEASE" ] || [ "$NEXT_RELEASE" == "$CURRENT_RELEASE" ]; then
    # Next Stop Release could not be found or is same as current Release then use whatever is available
    for r in $AVAILABLE_RELEASES; do
        nr="$(release2num $r)"
        if [ $nr -gt $CURRENT_RELEASE_NUM ]; then
            NEXT_RELEASE=$r
            break
        fi
    done
fi

if [ "$STAGE" == "2" ]; then
    if [ -z "$NEXT_RELEASE" ]; then
        echo "Can't find next release"
        exit 1
    fi
    echo "Next release: $NEXT_RELEASE"
fi

if [ "$STAGE" == "2" ] && [ "$NEXT_RELEASE" == "$CURRENT_RELEASE" ]; then
    echo "Can't find newer release than $CURRENT_RELEASE"   
    echo "Do you want to upgrade packages in current release anyway (not recommended)? [y/N]"
    read yn
    [[ "$yn" != [yY] ]] && exit 1
fi

NEXT_RELEASE_NUM="$(release2num $NEXT_RELEASE)"

if [ "$STAGE" == "1" ]; then
    # Download latest package and execute script again
    if [ "$NEXT_RELEASE_NUM" -ge 440 ]; then
        # add new repo url
        ssu ar hw_repo_tmp "https://repo.sailfishos.org/obs/nemo:/testing:/hw:/motorola:/moto_msm8960_jbbl:/$NEXT_RELEASE/sailfishos/"
    else
        ssu ar hw_repo_tmp "http://repo.merproject.org/obs/nemo:/testing:/hw:/motorola:/moto_msm8960_jbbl/sailfishos_$NEXT_RELEASE/"
    fi
    zypper ref hw_repo_tmp
    zypper --non-interactive in --force --from hw_repo_tmp sfos-moto_msm8960_jbbl-adaptation
    ssu rr hw_repo_tmp
    [ "$debug_mode" == "1" ] && exec $SCRIPT_PATH --debug --second || exec $SCRIPT_PATH --second 
fi

export NEXT_RELEASE
if [ "$debug_mode" == "1" ]; then
    bash -x /usr/share/sfos-moto_msm8960_jbbl-adaptation/real-upgrade.sh
else    
    /usr/share/sfos-moto_msm8960_jbbl-adaptation/real-upgrade.sh
fi


