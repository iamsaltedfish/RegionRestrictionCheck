#!/bin/bash

Font_Black="\033[30m"
Font_Red="\033[31m"
Font_Green="\033[32m"
Font_Yellow="\033[33m"
Font_Blue="\033[34m"
Font_Purple="\033[35m"
Font_SkyBlue="\033[36m"
Font_White="\033[37m"
Font_Suffix="\033[0m"

while getopts ":I:M:EX:P:" optname; do
    case "$optname" in
    "I")
        iface="$OPTARG"
        useNIC="--interface $iface"
        ;;
    "M")
        if [[ "$OPTARG" == "4" ]]; then
            NetworkType=4
        elif [[ "$OPTARG" == "6" ]]; then
            NetworkType=6
        fi
        ;;
    "E")
        language="e"
        ;;
    "X")
        XIP="$OPTARG"
        xForward="--header X-Forwarded-For:$XIP"
        ;;
    "P")
        proxy="$OPTARG"
        usePROXY="-x $proxy"
    	;;
    ":")
        echo "Unknown error while processing options"
        exit 1
        ;;
    esac

done

if [ -z "$iface" ]; then
    useNIC=""
fi

if [ -z "$XIP" ]; then
    xForward=""
fi

if [ -z "$proxy" ]; then
    usePROXY=""
elif [ -n "$proxy" ]; then
    NetworkType=4
fi

if ! mktemp -u --suffix=RRC &>/dev/null; then
    is_busybox=1
fi

UA_Browser="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/80.0.3987.87 Safari/537.36"
UA_Dalvik="Dalvik/2.1.0 (Linux; U; Android 9; ALP-AL00 Build/HUAWEIALP-AL00)"
WOWOW_Cookie=$(curl -s "https://raw.githubusercontent.com/lmc999/RegionRestrictionCheck/main/cookies" | awk 'NR==3')
TVer_Cookie="Accept: application/json;pk=BCpkADawqM0_rzsjsYbC1k1wlJLU4HiAtfzjxdUmfvvLUQB-Ax6VA-p-9wOEZbCEm3u95qq2Y1CQQW1K9tPaMma9iAqUqhpISCmyXrgnlpx9soEmoVNuQpiyGsTpePGumWxSs1YoKziYB6Wz"

green() {
	echo -e "\033[32m[info]\033[0m"
}

red() {
	echo -e "\033[31m[warn]\033[0m"
}

yellow() {
	echo -e "\033[33m[note]\033[0m"
}

blue() {
	echo -e "\033[34m[input]\033[0m"
}

checkOs() {
    ifTermux=$(echo $PWD | grep termux)
    ifMacOS=$(uname -a | grep Darwin)
    if [ -n "$ifTermux" ]; then
        os_version=Termux
    elif [ -n "$ifMacOS" ]; then
        os_version=MacOS
    else
        os_version=$(grep 'VERSION_ID' /etc/os-release | cut -d '"' -f 2 | tr -d '.')
    fi

    if [[ "$os_version" == "2004" ]] || [[ "$os_version" == "10" ]] || [[ "$os_version" == "11" ]]; then
        ssll="-k --ciphers DEFAULT@SECLEVEL=1"
    fi
}

checkDependencies() {

    os_detail=$(cat /etc/os-release 2>/dev/null)
    if_debian=$(echo $os_detail | grep 'ebian')
    if_redhat=$(echo $os_detail | grep 'rhel')

    if [ -n "$if_debian" ]; then
        InstallMethod="apt"
    elif [ -n "$if_redhat" ] && [[ "$os_version" -gt 7 ]]; then
        InstallMethod="dnf"
    elif [ -n "$if_redhat" ] && [[ "$os_version" -lt 8 ]]; then
        InstallMethod="yum"
    elif [[ "$os_version" == "Termux" ]]; then
        InstallMethod="pkg"
    elif [[ "$os_version" == "MacOS" ]]; then
        InstallMethod="brew"
    fi

    python -V >/dev/null 2>&1
    if [[ "$?" -ne "0" ]]; then
        python3 -V >/dev/null 2>&1
        if [[ "$?" -eq "0" ]]; then
            python3_patch=$(which python3)
            ln -s $python3_patch /usr/bin/python >/dev/null 2>&1
        else
            if [ -n "$if_debian" ]; then
                echo -e "${Font_Green}Installing python${Font_Suffix}"
                $InstallMethod update >/dev/null 2>&1
                $InstallMethod install python -y >/dev/null 2>&1
            elif [ -n "$if_redhat" ]; then
                echo -e "${Font_Green}Installing python${Font_Suffix}"
                if [[ "$os_version" -gt 7 ]]; then
                    $InstallMethod update >/dev/null 2>&1
                    $InstallMethod install python3 -y >/dev/null 2>&1
                    python3_patch=$(which python3)
                    ln -s $python3_patch /usr/bin/python
                else
                    $InstallMethod update >/dev/null 2>&1
                    $InstallMethod install python -y >/dev/null 2>&1
                fi

            elif [[ "$os_version" == "Termux" ]]; then
                echo -e "${Font_Green}Installing python${Font_Suffix}"
                $InstallMethod update -y >/dev/null 2>&1
                $InstallMethod install python -y >/dev/null 2>&1

            elif [[ "$os_version" == "MacOS" ]]; then
                echo -e "${Font_Green}Installing python${Font_Suffix}"
                $InstallMethod install python

            fi
        fi
    fi

    dig -v >/dev/null 2>&1
    if [[ "$?" -ne "0" ]]; then
        if [[ "$InstallMethod" == "apt" ]]; then
            echo -e "${Font_Green}Installing dnsutils${Font_Suffix}"
            $InstallMethod update >/dev/null 2>&1
            $InstallMethod install dnsutils -y >/dev/null 2>&1
        elif [[ "$InstallMethod" == "yum" ]]; then
            echo -e "${Font_Green}Installing bind-utils${Font_Suffix}"
            $InstallMethod update >/dev/null 2>&1
            $InstallMethod install bind-utils -y >/dev/null 2>&1
        elif [[ "$InstallMethod" == "pkg" ]]; then
            echo -e "${Font_Green}Installing dnsutils${Font_Suffix}"
            $InstallMethod update -y >/dev/null 2>&1
            $InstallMethod install dnsutils -y >/dev/null 2>&1
        elif [[ "$InstallMethod" == "brew" ]]; then
            echo -e "${Font_Green}Installing bind${Font_Suffix}"
            $InstallMethod install bind
        fi
    fi

    if [[ "$os_version" == "MacOS" ]]; then
        md5sum /dev/null >/dev/null 2>&1
        if [[ "$?" -ne "0" ]]; then
            echo -e "${Font_Green}Installing md5sha1sum${Font_Suffix}"
            $InstallMethod install md5sha1sum
        fi
    fi
}

MediaUnlockTest_BilibiliHKMCTW() {
    local randsession="$(cat /dev/urandom | head -n 32 | md5sum | head -c 32)"
    local result=$(curl $useNIC --user-agent "${UA_Browser}" -${1} -fsSL --max-time 10 "https://api.bilibili.com/pgc/player/web/playurl?avid=18281381&cid=29892777&qn=0&type=&otype=json&ep_id=183799&fourk=1&fnver=0&fnval=16&session=${randsession}&module=bangumi" 2>&1)

    if [[ "$result" != "curl"* ]]; then
        local result="$(echo "${result}" | python -m json.tool 2>/dev/null | grep '"code"' | head -1 | awk '{print $2}' | cut -d ',' -f1)"
        if [ "${result}" = "0" ]; then
            modifyJsonTemplate 'BilibiliHKMCTW_result' 'Yes'
        elif [ "${result}" = "-10403" ]; then
            modifyJsonTemplate 'BilibiliHKMCTW_result' 'No'
        else
            modifyJsonTemplate 'BilibiliHKMCTW_result' 'Unknow'
        fi
    else
        modifyJsonTemplate 'BilibiliHKMCTW_result' 'Unknow'
    fi
}

MediaUnlockTest_BilibiliTW() {
    local randsession="$(cat /dev/urandom | head -n 32 | md5sum | head -c 32)"
    local result=$(curl $useNIC --user-agent "${UA_Browser}" -${1} -fsSL --max-time 10 "https://api.bilibili.com/pgc/player/web/playurl?avid=50762638&cid=100279344&qn=0&type=&otype=json&ep_id=268176&fourk=1&fnver=0&fnval=16&session=${randsession}&module=bangumi" 2>&1)

    if [[ "$result" != "curl"* ]]; then
        local result="$(echo "${result}" | python -m json.tool 2>/dev/null | grep '"code"' | head -1 | awk '{print $2}' | cut -d ',' -f1)"
        if [ "${result}" = "0" ]; then
            modifyJsonTemplate 'BilibiliTW_result' 'Yes'
        elif [ "${result}" = "-10403" ]; then
            modifyJsonTemplate 'BilibiliTW_result' 'No'
        else
            modifyJsonTemplate 'BilibiliTW_result' 'Unknow'
        fi
    else
        modifyJsonTemplate 'BilibiliTW_result' 'Unknow'
    fi
}

MediaUnlockTest_AbemaTV_IPTest() {
    local tempresult=$(curl $useNIC --user-agent "${UA_Dalvik}" -${1} -fsL --write-out %{http_code} --max-time 10 "https://api.abema.io/v1/ip/check?device=android" 2>&1)

    if [[ "$tempresult" == "000" ]]; then
        modifyJsonTemplate 'AbemaTV_result' 'Unknow'
        return
    fi

    result=$(curl $useNIC --user-agent "${UA_Dalvik}" -${1} -fsL --max-time 10 "https://api.abema.io/v1/ip/check?device=android" | python -m json.tool 2>/dev/null | grep isoCountryCode | awk '{print $2}' | cut -f2 -d'"')

    if [ -n "$result" ]; then
        if [[ "$result" == "JP" ]]; then
            modifyJsonTemplate 'AbemaTV_result' 'Yes'
        else
            modifyJsonTemplate 'AbemaTV_result' 'Yes' 'Oversea Only'
        fi
    else
        modifyJsonTemplate 'AbemaTV_result' 'No'
    fi
}

MediaUnlockTest_BBCiPLAYER() {
    local tmpresult=$(curl $useNIC --user-agent "${UA_Browser}" -${1} ${ssll} -fsL --max-time 10 https://open.live.bbc.co.uk/mediaselector/6/select/version/2.0/mediaset/pc/vpid/bbc_one_london/format/json/jsfunc/JS_callbacks0)

    if [ "${tmpresult}" = "000" ]; then
        modifyJsonTemplate 'BBC_result' 'Unknow'
        return

    fi

    if [ -n "$tmpresult" ]; then
        result=$(echo $tmpresult | grep 'geolocation')
        if [ -n "$result" ]; then
            modifyJsonTemplate 'BBC_result' 'No'
        else
            modifyJsonTemplate 'BBC_result' 'Yes'
        fi
    else
        modifyJsonTemplate 'BBC_result' 'Unknow'
    fi
}

MediaUnlockTest_Netflix() {
    local result1=$(curl $useNIC $usePROXY $xForward -${1} --user-agent "${UA_Browser}" -fsL --write-out %{http_code} --output /dev/null --max-time 10 "https://www.netflix.com/title/81280792" 2>&1)

    if [[ "$result1" == "404" ]]; then
        modifyJsonTemplate 'Netflix_result' 'No' 'Originals Only'
        return
    elif [[ "$result1" == "403" ]]; then
        modifyJsonTemplate 'Netflix_result' 'No'
        return
    elif [[ "$result1" == "200" ]]; then
        local region=$(curl $useNIC $usePROXY $xForward -${1} --user-agent "${UA_Browser}" -fs --max-time 10 --write-out %{redirect_url} --output /dev/null "https://www.netflix.com/title/80018499" | cut -d '/' -f4 | cut -d '-' -f1 | tr [:lower:] [:upper:])
        if [[ ! -n "$region" ]]; then
            region="US"
        fi
        modifyJsonTemplate 'Netflix_result' 'Yes' "${region}"
        return
    elif [[ "$result1" == "000" ]]; then
        modifyJsonTemplate 'Netflix_result' 'Unknow'
        return
    fi
}

MediaUnlockTest_YouTube_Premium() {
    local tmpresult=$(curl $useNIC -${1} -sS -H "Accept-Language: en" "https://www.youtube.com/premium" 2>&1)
    local region=$(curl $useNIC --user-agent "${UA_Browser}" -${1} -sL --max-time 10 "https://www.youtube.com/premium" | grep "countryCode" | sed 's/.*"countryCode"//' | cut -f2 -d'"')

    if [ -n "$region" ]; then
        sleep 0
    else
        isCN=$(echo $tmpresult | grep 'www.google.cn')
        if [ -n "$isCN" ]; then
            region=CN
        else
            region=US
        fi
    fi

    if [[ "$tmpresult" == "curl"* ]]; then
        modifyJsonTemplate 'YouTube_Premium_result' 'Unknow'
        return
    fi

    local result=$(echo $tmpresult | grep 'Premium is not available in your country')
    if [ -n "$result" ]; then
        modifyJsonTemplate 'YouTube_Premium_result' 'No' "${region}"
        return

    fi

    local result=$(echo $tmpresult | grep 'manageSubscriptionButton')
    if [ -n "$result" ]; then
        modifyJsonTemplate 'YouTube_Premium_result' 'Yes' "${region}"
        return
    else
        modifyJsonTemplate 'YouTube_Premium_result' 'Unknow'
    fi
}

MediaUnlockTest_DisneyPlus() {
    local PreAssertion=$(curl $useNIC -${1} --user-agent "${UA_Browser}" -s --max-time 10 -X POST "https://global.edge.bamgrid.com/devices" -H "authorization: Bearer ZGlzbmV5JmJyb3dzZXImMS4wLjA.Cu56AgSfBTDag5NiRA81oLHkDZfu5L3CKadnefEAY84" -H "content-type: application/json; charset=UTF-8" -d '{"deviceFamily":"browser","applicationRuntime":"chrome","deviceProfile":"windows","attributes":{}}' 2>&1)

    if [[ "$PreAssertion" == "curl"* ]] && [[ "$1" == "6" ]]; then
        echo -n -e "\r Disney+:\t\t\t\t${Font_Red}IPv6 Not Support${Font_Suffix}\n"
        return
    elif [[ "$PreAssertion" == "curl"* ]]; then
        modifyJsonTemplate 'DisneyPlus_result' 'Unknow'
        return
    fi

    local assertion=$(echo $PreAssertion | python -m json.tool 2>/dev/null | grep assertion | cut -f4 -d'"')
    local PreDisneyCookie=$(curl -s --max-time 10 "https://raw.githubusercontent.com/lmc999/RegionRestrictionCheck/main/cookies" | sed -n '1p')
    local disneycookie=$(echo $PreDisneyCookie | sed "s/DISNEYASSERTION/${assertion}/g")
    local TokenContent=$(curl $useNIC -${1} --user-agent "${UA_Browser}" -s --max-time 10 -X POST "https://global.edge.bamgrid.com/token" -H "authorization: Bearer ZGlzbmV5JmJyb3dzZXImMS4wLjA.Cu56AgSfBTDag5NiRA81oLHkDZfu5L3CKadnefEAY84" -d "$disneycookie")
    local isBanned=$(echo $TokenContent | python -m json.tool 2>/dev/null | grep 'forbidden-location')
    local is403=$(echo $TokenContent | grep '403 ERROR')

    if [ -n "$isBanned" ] || [ -n "$is403" ]; then
        modifyJsonTemplate 'DisneyPlus_result' 'No'
        return
    fi

    local fakecontent=$(curl -s --max-time 10 "https://raw.githubusercontent.com/lmc999/RegionRestrictionCheck/main/cookies" | sed -n '8p')
    local refreshToken=$(echo $TokenContent | python -m json.tool 2>/dev/null | grep 'refresh_token' | awk '{print $2}' | cut -f2 -d'"')
    local disneycontent=$(echo $fakecontent | sed "s/ILOVEDISNEY/${refreshToken}/g")
    local tmpresult=$(curl $useNIC -${1} --user-agent "${UA_Browser}" -X POST -sSL --max-time 10 "https://disney.api.edge.bamgrid.com/graph/v1/device/graphql" -H "authorization: ZGlzbmV5JmJyb3dzZXImMS4wLjA.Cu56AgSfBTDag5NiRA81oLHkDZfu5L3CKadnefEAY84" -d "$disneycontent" 2>&1)
    local previewcheck=$(curl $useNIC -${1} -s -o /dev/null -L --max-time 10 -w '%{url_effective}\n' "https://disneyplus.com" | grep preview)
    local isUnabailable=$(echo $previewcheck | grep 'unavailable')
    local region=$(echo $tmpresult | python -m json.tool 2>/dev/null | grep 'countryCode' | cut -f4 -d'"')
    local inSupportedLocation=$(echo $tmpresult | python -m json.tool 2>/dev/null | grep 'inSupportedLocation' | awk '{print $2}' | cut -f1 -d',')

    if [[ "$region" == "JP" ]]; then
        modifyJsonTemplate 'DisneyPlus_result' 'Yes' 'JP'
        return
    elif [ -n "$region" ] && [[ "$inSupportedLocation" == "false" ]] && [ -z "$isUnabailable" ]; then
        modifyJsonTemplate 'DisneyPlus_result' 'No'
        return
    elif [ -n "$region" ] && [ -n "$isUnavailable" ]; then
        modifyJsonTemplate 'DisneyPlus_result' 'No'
        return
    elif [ -n "$region" ] && [[ "$inSupportedLocation" == "true" ]]; then
        modifyJsonTemplate 'DisneyPlus_result' 'Yes' "${region}"
        return
    elif [ -z "$region" ]; then
        modifyJsonTemplate 'DisneyPlus_result' 'No'
        return
    else
        modifyJsonTemplate 'DisneyPlus_result' 'Unknow'
        return
    fi
}

MediaUnlockTest_MyTVSuper() {
    local result=$(curl $useNIC -s -${1} --max-time 10 https://www.mytvsuper.com/iptest.php | grep 'HK')

    if [ -n "$result" ]; then
        modifyJsonTemplate 'MyTVSuper_result' 'Yes'
        return
    else
        modifyJsonTemplate 'MyTVSuper_result' 'No'
        return
    fi

    modifyJsonTemplate 'MyTVSuper_result' 'Unknow'
}

createJsonTemplate() {
    echo '{
    "YouTube": "YouTube_Premium_result",
    "Netflix": "Netflix_result",
    "DisneyPlus": "DisneyPlus_result",
    "BilibiliHKMCTW": "BilibiliHKMCTW_result",
    "BilibiliTW": "BilibiliTW_result",
    "MyTVSuper": "MyTVSuper_result",
    "BBC": "BBC_result",
    "Abema": "AbemaTV_result"
}' >/root/media_test_tpl.json
}

modifyJsonTemplate() {
    key_word=$1
    result=$2
    region=$3

    if [[ "$3" == "" ]]; then
        sed -i "s#${key_word}#${result}#g" /root/media_test_tpl.json
    else
        sed -i "s#${key_word}#${result} (${region})#g" /root/media_test_tpl.json
    fi
}

setCronTask() {
    addTask() {
        execution_time_interval=$1
        
        crontab -l >/root/crontab.list
        echo "0 */${execution_time_interval} * * * /bin/bash /root/csm.sh" >>/root/crontab.list
        crontab /root/crontab.list
        rm -rf /root/crontab.list
        echo -e "$(green) The scheduled task is added successfully."
    }

    crontab -l | grep "csm.sh" >/dev/null
    if [[ "$?" != "0" ]]; then
        echo "[1] 1 hour"
        echo "[2] 2 hour"
        echo "[3] 3 hour"
        echo "[4] 4 hour"
        echo "[5] 6 hour"
        echo "[6] 8 hour"
        echo "[7] 12 hour"
        echo "[8] 24 hour"
        echo
        read -p "$(blue) Please select the detection frequency and enter the serial number (eg: 1):" time_interval_id

        if [[ "${time_interval_id}" == "5" ]];then
            time_interval=6
        elif [[ "${time_interval_id}" == "6" ]];then
            time_interval=8
        elif [[ "${time_interval_id}" == "7" ]];then
            time_interval=12
        elif [[ "${time_interval_id}" == "8" ]];then
            time_interval=24
        else
            time_interval=$time_interval_id
        fi

        case "${time_interval_id}" in
            [1-8])
                addTask ${time_interval};;
            *)
                echo -e "$(red) Choose one from the list given and enter the sequence number."
                exit;;
        esac
    fi
}

checkConfig() {
    getConfig() {
        read -p "$(blue) Please enter the panel address (eg: https://demo.sspanel.org):" panel_address
        read -p "$(blue) Please enter the mu key:" mu_key
        read -p "$(blue) Please enter the node id:" node_id

        if [[ "${panel_address}" = "" ]] || [[ "${mu_key}" = "" ]];then
            echo -e "$(red) Complete all necessary parameter entries."
            exit
        fi
        
        curl -s "${panel_address}/mod_mu/nodes?key=${mu_key}" | grep "invalid" > /dev/null
        if [[ "$?" = "0" ]];then
            echo -e "$(red) Wrong website address or mukey error, please try again."
            exit
        fi

        echo "${panel_address}" > /root/.csm.config
        echo "${mu_key}" >> /root/.csm.config
        echo "${node_id}" >> /root/.csm.config
    }

    if [[ ! -e "/root/.csm.config" ]];then
        getConfig
    fi
}

postData() {
    if [[ ! -e "/root/.csm.config" ]];then
        echo -e "$(red) Missing configuration file."
        exit
    fi
    if [[ ! -e "/root/media_test_tpl.json" ]];then
        echo -e "$(red) Missing detection report."
        exit
    fi
    
    panel_address=$(sed -n 1p /root/.csm.config)
    mu_key=$(sed -n 2p /root/.csm.config)
    node_id=$(sed -n 3p /root/.csm.config)

    curl -s -X POST -d "content=$(cat /root/media_test_tpl.json | base64 | xargs echo -n | sed 's# ##g')" "${panel_address}/mod_mu/media/saveReport?key=${mu_key}&node_id=${node_id}" > /dev/null

    rm -rf /root/media_test_tpl.json
}

printInfo() {
    green_start='\033[32m'
    color_end='\033[0m'
    
    echo -e "${green_start}The code for this script to detect streaming media unlocking is all from the open source project https://github.com/lmc999/RegionRestrictionCheck , and the open source protocol is AGPL-3.0. This script is open source as required by the open source license. Thanks to the original author @lmc999 and everyone who made the pull request for this project for their contributions.${color_end}"
    echo
    echo -e "${green_start}Project: https://github.com/iamsaltedfish/check-stream-media${color_end}"
    echo -e "${green_start}Author: @iamsaltedfish${color_end}"
    echo -e "${green_start}2022-12-19 v.1.0.5${color_end}"
}

runCheck() {
    createJsonTemplate
    MediaUnlockTest_BBCiPLAYER 4
    MediaUnlockTest_MyTVSuper 4
    MediaUnlockTest_BilibiliHKMCTW 4
    MediaUnlockTest_BilibiliTW 4
    MediaUnlockTest_AbemaTV_IPTest 4
    MediaUnlockTest_Netflix 4
    MediaUnlockTest_YouTube_Premium 4
    MediaUnlockTest_DisneyPlus 4
}

main() {
    checkOs
    checkDependencies
    setCronTask
    checkConfig
    runCheck
    postData
    printInfo
}

main
