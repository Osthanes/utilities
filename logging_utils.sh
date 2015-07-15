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
        BMIX_TARGET_PREFIX="logs.stage1"
        APT_TARGET_PREFIX="logmet.stage1"
    else
        BMIX_TARGET_PREFIX="logs"
        APT_TARGET_PREFIX="logmet"
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
    wget https://${APT_TARGET_PREFIX}.opvis.bluemix.net:5443/apt/BM_OpVis_repo.gpg
    echo "deb https://${APT_TARGET_PREFIX}.opvis.bluemix.net:5443/apt stable main" > /etc/apt/sources.list.d/BM_opvis_repo.list
    apt-get update
    cd $cur_dir

    # install the logstash forwarder
    apt-get -y install mt-logstash-forwarder

    # setup up its configuration
    if [ -e "/etc/mt-logstash-forwarder/mt-lsf-config.sh" ]; then
        rm -f /etc/mt-logstash-forwarder/mt-lsf-config.sh
    fi
    echo "LSF_INSTANCE_ID=\"${BMIX_USER}-pipeline\"" >>/etc/mt-logstash-forwarder/mt-lsf-config.sh
    echo "LSF_TARGET=\"${BMIX_TARGET_PREFIX}.opvis.bluemix.net:9091\"" >>/etc/mt-logstash-forwarder/mt-lsf-config.sh
    echo "LSF_TENANT_ID=\"${LOG_SPACE_ID}\"" >>/etc/mt-logstash-forwarder/mt-lsf-config.sh
    echo "LSF_PASSWORD=\"${LOG_LOGGING_TOKEN}\"" >>/etc/mt-logstash-forwarder/mt-lsf-config.sh
    echo "LSF_GROUP_ID=\"${BMIX_ORG}-pipeline\"" >>/etc/mt-logstash-forwarder/mt-lsf-config.sh

    # setup the logfile to track
    if [ -z "$EXT_DIR" ]; then
        export EXT_DIR=`pwd`
    fi
    export PIPELINE_LOGGING_FILE=$EXT_DIR/pipeline_tracking.log
    # start it empty
    if [ -e "$PIPELINE_LOGGING_FILE" ]; then
        rm -f "$PIPELINE_LOGGING_FILE"
    fi
    echo "" > "$PIPELINE_LOGGING_FILE"

    # point logstash forwarder to read that file
    PIPELINE_LOG_CONF_FILENAME="/etc/mt-logstash-forwarder/conf.d/pipeline_log.conf"
    PIPELINE_LOG_CONF_TEMPLATE="{\"files\": [ { \"paths\": [ \"${PIPELINE_LOGGING_FILE}\" ] } ] }"

    if [ -e "$PIPELINE_LOG_CONF_FILENAME" ]; then
        rm -f "$PIPELINE_LOG_CONF_FILENAME"
    fi

    echo -e "$PIPELINE_LOG_CONF_TEMPLATE" > "$PIPELINE_LOG_CONF_FILENAME"

    # restart forwarder to pick up the config changes
    service mt-logstash-forwarder restart

    # flag logging enabled for other extensions to use
    export LOGMET_LOGGING_ENABLED=1
    return 0
}

DEBUGGING="DEBUGGING_LEVEL"
INFO="INFO_LEVEL"
LABEL="LABEL_LEVEL"
WARN="WARN_LEVEL"
ERROR="ERROR_LEVEL"

DEBUGGING_LEVEL=6
INFO_LEVEL=4
WARN_LEVEL=2
ERROR_LEVEL=1
OFF_LEVEL=0


if [ -z "$ERROR_LOG_FILE" ]; then
    ERROR_LOG_FILE="${EXT_DIR}/errors.log"
    export ERROR_LOG_FILE
fi


log_and_echo() {
    if [ -z "$LOGGER_LEVEL" ]; then
        if [[ $DEBUG = 1 ]]; then
            #setting as local so other code won't think it has been set externally
            local LOGGER_LEVEL=$DEBUGGING_LEVEL
        else
            #setting as local so other code won't think it has been set externally
            local LOGGER_LEVEL=$INFO_LEVEL
        fi
    fi
    local MSG_TYPE="$1"
    if [ "$INFO" == "$MSG_TYPE" ]; then
        shift
        local pre=""
        local post=""
        local MSG_LEVEL=$INFO_LEVEL
    elif [ "$DEBUGGING" == "$MSG_TYPE" ]; then
        shift
        local pre=""
        local post=""
        local MSG_LEVEL=$DEBUGGING_LEVEL
    elif [ "$LABEL" == "$MSG_TYPE" ]; then
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
    if [ $LOGGER_LEVEL -ge $MSG_LEVEL ]; then
        echo "$D_MSG"
    fi
    if [ "$ERROR" == "$MSG_TYPE" ]; then
        #store the error for later
        echo "$D_MSG" >> "$ERROR_LOG_FILE"
    fi
    # always log
    if [ -n "$PIPELINE_LOGGING_FILE" ]; then
        if [ -e $PIPELINE_LOGGING_FILE ]; then
            local timestamp=`date +"%F %T %Z"`
            echo "{\"@timestamp\": \"${timestamp}\", \"level\": \"${MSG_LEVEL}\", \"message\": \"$L_MSG\"}" >> "$PIPELINE_LOGGING_FILE"
        else
            # no logger file, send to syslog
            logger -t "pipeline" "$L_MSG"
        fi
    else
        # no logger file, send to syslog
        logger -t "pipeline" "$L_MSG"
    fi
}


print_errors() {
    if [ -e "${ERROR_LOG_FILE}" ]; then
        local ERROR_COUNT=`wc "${ERROR_LOG_FILE}" | awk '{print $1}'` 
        if [ ${ERROR_COUNT} -eq 1 ]; then
            echo -e "${label_color}There was ${ERROR_COUNT} error recorded during execution:${no_color}"
        else
            echo -e "${label_color}There were ${ERROR_COUNT} errors recorded during execution:${no_color}"
        fi
        cat "${ERROR_LOG_FILE}"
    fi
    #No output if no errors were recorded
    
}

# begin main execution sequence

export -f setup_met_logging
export -f log_and_echo
export -f print_errors
# export message types for log_and_echo
# ERRORs will be collected
export DEBUGGING
export INFO
export LABEL
export WARN
export ERROR

#export logging levels for log_and_echo
# messages will be echoed if LOGGER_LEVEL is set to or above the LEVEL
# messages are always logged
# default LOGGER_LEVEL is INFO_LEVEL, unless DEBUG=1, then DEBUGGING_LEVEL
export DEBUGGING_LEVEL
export INFO_LEVEL
export WARN_LEVEL
export ERROR_LEVEL
export OFF_LEVEL

