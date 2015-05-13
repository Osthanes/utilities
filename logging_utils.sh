#!/bin/bash

#********************************************************************************
# Copyright 2015 IBM
#
#   Licensed under the Apache License, Version 2.0 (the "License");
#   you may not use this file except in compliance with the License.
#   You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
#   Unless required by applicable law or agreed to in writing, software
#   distributed under the License is distributed on an "AS IS" BASIS,
#   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#   See the License for the specific language governing permissions and
#********************************************************************************

# uncomment the next line to debug this script
#set -x

# get a value which came from a line like "name": "value",
# trim quotes, spaces, comma from value if needed before returning
get_trimmed_value() {
    local trimmedString=$1
    if [ "${trimmedString}x" == "x" ]; then
        echo
        return
    fi
    # trim leading and trailing spaces, if any
    trimmedString="$(echo -e ${trimmedString} | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
    # remove leading "
    trimmedString="${trimmedString#\"}"
    # remove trailing , if there is one
    trimmedString="${trimmedString%,}"
    # remove trailing "
    trimmedString="${trimmedString%\"}"
    
    echo "$trimmedString"
}

# set up for calls to the logging service - takes parameters
# User   : required, bluemix userid
# Pwd    : required, bluemix password
# Space  : required, bluemix space
# Org    : required, bluemix org
# Target : optional, may be 'prod' or 'staging'.  defaults to 'prod'
setup_met_logging() {
    local BMIX_USER=""
    local BMIX_PWD=""
    local BMIX_SPACE=""
    local BMIX_ORG=""
    local BMIX_TARGET=""
    local BMIX_TARGET_PREFIX=""

    if [ -z $1 ]; then
        # missing bluemix username
        return 1
    else
        BMIX_USER=$1
    fi
    if [ -z $2 ]; then
        # missing bluemix password
        return 2
    else
        BMIX_PWD=$2
    fi
    if [ -z $3 ]; then
        # missing bluemix space
        return 3
    else
        BMIX_SPACE=$3
    fi
    if [ -z $4 ]; then
        # missing bluemix org
        return 4
    else
        BMIX_ORG=$4
    fi
    if [ -z $5 ]; then
        # empty target, set to prod
        BMIX_TARGET='prod'
    else
        BMIX_TARGET=$5
    fi

    # adjust logging system for prod/staging
    if [ "${BMIX_TARGET}x" == "stagingx" ]; then
        BMIX_TARGET_PREFIX="logmet.stage1"
    else
        BMIX_TARGET_PREFIX="logmet"
    fi

    # get our necessary logging keys
    local curl_data="user=${BMIX_USER}&passwd=${BMIX_PWD}&space=${BMIX_SPACE}&organization=${BMIX_ORG}"
    curl -k --silent -d "$curl_data" https://${BMIX_TARGET_PREFIX}.ng.bluemix.net/login > logmet.setup.info
    local RC=$?
    local local_val=""
    if [ $RC == 0 ]; then
        while read -r line || [[ -n $line ]]; do 
            if [[ $line == *"\"access_token\":"* ]]; then
                local_val=$(get_trimmed_value "${line#*:}")
                if [ "${local_val}x" != "x" ]; then
                    export LOG_ACCESS_TOKEN=$local_val
                fi
            elif [[ $line == *"\"logging_token\":"* ]]; then
                local_val=$(get_trimmed_value "${line#*:}")
                if [ "${local_val}x" != "x" ]; then
                    export LOG_LOGGING_TOKEN=$local_val
                fi
            elif [[ $line == *"\"space_id\":"* ]]; then
                local_val=$(get_trimmed_value "${line#*:}")
                if [ "${local_val}x" != "x" ]; then
                    export LOG_SPACE_ID=$local_val
                fi
            fi
        done <logmet.setup.info
        rm logmet.setup.info
    else
        rm logmet.setup.info
        # unable to curl our tokens, fail out
        return 10
    fi

    # setup our repo
    local cur_dir=`pwd`
    cd /etc/apt/trusted.gpg.d
    wget https://${BMIX_TARGET_PREFIX}.opvis.bluemix.net:5443/apt/BM_OpVis_repo.gpg
    echo "deb https://${BMIX_TARGET_PREFIX}.opvis.bluemix.net:5443/apt stable main" > /etc/apt/sources.list.d/BM_opvis_repo.list
    apt-get update
    cd $cur_dir

    # install the logstash forwarder
    apt-get -y install mt-logstash-forwarder

    # setup up its configuration
    echo "LSF_INSTANCE_ID=\"${BMIX_USER}-pipeline\"" >>/etc/mt-logstash-forwarder/mt-lsf-config.sh
    echo "LSF_TARGET=\"${BMIX_TARGET_PREFIX}.opvis.bluemix.net:9091\"" >>/etc/mt-logstash-forwarder/mt-lsf-config.sh
    echo "LSF_TENANT_ID=\"${LOG_SPACE_ID}\"" >>/etc/mt-logstash-forwarder/mt-lsf-config.sh
    echo "LSF_PASSWORD=\"${LOG_LOGGING_TOKEN}\"" >>/etc/mt-logstash-forwarder/mt-lsf-config.sh
    echo "LSF_GROUP_ID=\"${BMIX_ORG}-pipeline\"" >>/etc/mt-logstash-forwarder/mt-lsf-config.sh

    # restart it to pick up the config changes
    service mt-logstash-forwarder restart

    # flag logging enabled for other extensions to use
    export LOGMET_LOGGING_ENABLED=1
    return 0
}

INFO="INFO_LEVEL"
LABEL="LABEL_LEVEL"
WARN="WARN_LEVEL"
ERROR="ERROR_LEVEL"

INFO_LEVEL=4
WARN_LEVEL=2
ERROR_LEVEL=1
OFF_LEVEL=0

ERROR_ARRAY=()



log_and_echo() {
    if [ -z "$LOGGER_LEVEL" ]; then
        #setting as local so other code won't think it has been set externally
        local LOGGER_LEVEL=$WARN_LEVEL
    fi
    local MSG_TYPE="$1"
    if [ "$INFO" == "$MSG_TYPE" ]; then
        shift
        local pre=""
        local post=""
        local MSG_LEVEL=$INFO_LEVEL
    elif [ "$LABEL" == "$MSG_TYPE"]; then
        shift
        local pre="${label_color}"
        local post="${no_color}"
        local MSG_LEVEL=$INFO_LEVEL
    elif [ "$WARN" == "$MSG_TYPE" ]; then
        shift
        local pre="${label_color}"
        local post="${no_color}"
        local MSG_LEVEL=$WARN_LEVEL
    elif [ "$ERROR" == "$MSG_TYPE" ]; then
        shift
        local pre="${red}"
        local post="${no_color}"
        local MSG_LEVEL=$ERROR_LEVEL
    else
        #NO MSG type specified; fall through to INFO level
        #Do not shift
        local pre=""
        local post=""
        local MSG_LEVEL=$INFO_LEVEL
    fi
    local L_MSG=`echo -e "$*"`
    local D_MSG=`echo -e "${pre}${L_MSG}${post}"`
    echo "$D_MSG"
    if [ "$ERROR" == "$MSG_TYPE" ]; then
        #store the error for later
        ERROR_ARRAY+=("$D_MSG")
    fi
    if [ $LOGGER_LEVEL -ge $MSG_LEVEL ]; then
        logger --tag "pipeline" "$L_MSG"
    fi
}

print_errors() {
    if [ -n "${ERROR_ARRAY}" ]; then
        if [ ${#ERROR_ARRAY[@]} -eq 1 ]; then
            echo -e "${label_color}There was ${#ERROR_ARRAY[@]} error during execution:${no_color}"
        else
            echo -e "${label_color}There were ${#ERROR_ARRAY[@]} errors during execution:${no_color}"
        fi
        for error in "${ERROR_ARRAY[@]}"; do
            echo "${error}"
        done
    
    else
        echo "There were no errors logged"
    fi
    
}

# begin main execution sequence

export -f setup_met_logging
export -f log_and_echo
export -f print_errors
# export message types for log_and_echo
# ERRORs will be collected
export INFO
export LABEL
export WARN
export ERROR

#export logging levels for log_and_echo
# messages will be logged if LOGGER_LEVEL is set to or above the LEVEL
# default LOGGER_LEVEL is WARN_LEVEL
export INFO_LEVEL
export WARN_LEVEL
export ERROR_LEVEL
export OFF_LEVEL
