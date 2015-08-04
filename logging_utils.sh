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

debugme() {
  [[ $DEBUG = 1 ]] && "$@" || :
}

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

# setup repository
# install mt-logstash-forwarder
install_logstash_forwarder() {
    if [ -z $1 ]; then
        debugme echo "Log init failed, missing target prefix"
        return 11
    else
        TARGET_PREFIX=$1
    fi
    # setup our repo
    debugme echo "Fetching setup the repository for apt target prefix: ${TARGET_PREFIX} "
    wget https://${TARGET_PREFIX}.opvis.bluemix.net:5443/apt/BM_OpVis_repo.gpg
    RC=$?
    if [ $RC -ne 0 ]; then
        debugme echo "Log init failed, wget BM_OpVis_repo.gpg failed, rc = $RC"
        return 12
    else
        sudo mv BM_OpVis_repo.gpg /etc/apt/trusted.gpg.d/.
    fi
    echo "deb https://${TARGET_PREFIX}.opvis.bluemix.net:5443/apt stable main" > BM_opvis_repo.list
    if [ $RC -ne 0 ]; then
        debugme echo "Log init failed, echo deb url to BM_opvis_repo.list failed, rc = $RC"
        return 13
    else
        sudo mv BM_opvis_repo.list /etc/apt/sources.list.d/.
    fi
    # get update
    debugme echo "run sudo apt-get update"
    sudo apt-get update >/dev/null

    # install the logstash forwarder
    debugme echo "install the logstash forwarder"
    local cur_dir=`pwd`
    cd /etc/apt/trusted.gpg.d
    sudo apt-get -y install mt-logstash-forwarder >/dev/null
    RC=$?
    if [ $RC -ne 0 ]; then
        debugme echo "Log init failed, could not install the logstash forwarder, rc = $RC"
        cd $cur_dir
        return 14
    fi
    cd $cur_dir
    return 0
}

# set up for calls to the logging service - takes parameters
# User   : required, bluemix userid
# Pwd    : required, bluemix password
setup_met_logging() {
    local BMIX_USER=""
    local BMIX_PWD=""
    local BMIX_SPACE=""
    local BMIX_ORG=""
    local BMIX_TARGET=""
    local BMIX_TARGET_PREFIX=""
    local RC=0

    if [ -z $1 ]; then
        debugme echo "Log init failed, missing bluemix username"
        return 1
    else
        BMIX_USER=$1
    fi
    if [ -z $2 ]; then
        debugme echo "Log init failed, missing bluemix password"
        return 2
    else
        BMIX_PWD=$2
    fi   
    # get bluemix space and org
    if [ -z "$BLUEMIX_SPACE" ] || [ -z "$BLUEMIX_ORG" ]; then 
        ice_retry_save_output info 2>/dev/null
        RC=$?
        if [ $RC -eq 0 ]; then
            local ICEINFO=$(cat iceretry.log)
            BMIX_SPACE=$(echo "$ICEINFO" | grep "Bluemix Space" | awk '{print $4}')
            BMIX_ORG=$(echo "$ICEINFO" | grep "Bluemix Org" | awk '{print $4}')
        else
            BMIX_SPACE=$(cf target | grep "Space" | awk '{print $2}')
            BMIX_ORG=$(cf space "$BMIX_SPACE" | grep "Org" | awk '{print $2}')
        fi
    else
        BMIX_SPACE="$BLUEMIX_SPACE"
        BMIX_ORG="$BLUEMIX_ORG"
    fi
    # get bluemix target
    if [ -n "$BLUEMIX_TARGET" ]; then
        BMIX_TARGET=$BLUEMIX_TARGET
    else
        BLUEMIX_API_HOST=`echo cf api | awk '{print $3}' | sed '0,/.*\/\//s///'`
        echo $BLUEMIX_API_HOST | grep 'stage1'
        RC=$?
        if [ $RC -eq 0 ]; then
            BMIX_TARGET="staging"
        else
            BMIX_TARGET="prod"
        fi
    fi
    # adjust logging system for prod/staging
    if [ "${BMIX_TARGET}x" == "stagingx" ]; then
        BMIX_TARGET_PREFIX="logs.stage1"
        APT_TARGET_PREFIX="logmet.stage1"
    else
        BMIX_TARGET_PREFIX="logs"
        APT_TARGET_PREFIX="logmet"
    fi
    # check the space, org and target
    if [ -z $BMIX_SPACE ]; then
        debugme echo "Log init failed, no space"
        return 3
    fi
    if [ -z $BMIX_ORG ]; then
        debugme echo "Log init failed, no org"
        return 4
    fi
    if [ -z $BMIX_TARGET ]; then
        debugme echo "Log init failed, no target"
        return 5
    fi
    # get our necessary logging keys
    debugme echo "Fetching logging keys for user: $BMIX_USER space: $BMIX_SPACE org: $BMIX_ORG "
    local curl_data="user=${BMIX_USER}&passwd=${BMIX_PWD}&space=${BMIX_SPACE}&organization=${BMIX_ORG}"
    curl -k --silent -d "$curl_data" https://${APT_TARGET_PREFIX}.ng.bluemix.net/login > logmet.setup.info
    RC=$?
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
        debugme echo "Log init failed, could not get tokens, rc = $RC"
        return 10
    fi

    # install logstash-forwarder
    # this may move into the base image
#    install_logstash_forwarder "${APT_TARGET_PREFIX}"
#    RC=$?
#    if [ $RC -ne 0 ]; then
#        return $RC
#    fi

    if [ -e "/etc/mt-logstash-forwarder/mt-lsf-config.sh" ]; then
        sudo rm -f /etc/mt-logstash-forwarder/mt-lsf-config.sh
        echo "File /etc/mt-logstash-forwarder/mt-lsf-config.sh deleted"
    else
        echo "File /etc/mt-logstash-forwarder/mt-lsf-config.sh does not exist"
    fi
    ls /etc/mt-logstash-forwarder
    echo "LSF_INSTANCE_ID=\"${BMIX_USER}-pipeline\"" >> mt-lsf-config.sh
    echo "LSF_TARGET=\"${BMIX_TARGET_PREFIX}.opvis.bluemix.net:9091\"" >> mt-lsf-config.sh
    echo "LSF_TENANT_ID=\"${LOG_SPACE_ID}\"" >> mt-lsf-config.sh
    echo "LSF_PASSWORD=\"${LOG_LOGGING_TOKEN}\"" >> mt-lsf-config.sh
    echo "LSF_GROUP_ID=\"${BMIX_ORG}-pipeline\"" >> mt-lsf-config.sh
    sudo mv mt-lsf-config.sh /etc/mt-logstash-forwarder/.

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

    # point logstash forwarder to read config files
    mkdir ${EXT_DIR}/conf.d
    PIPELINE_LOG_CONF_DIR="${EXT_DIR}/conf.d"
    PIPELINE_LOG_CONF_FILENAME="pipeline_log.conf"
    PIPELINE_LOG_CONF_TEMPLATE="{\"files\": [ { \"paths\": [ \"${PIPELINE_LOGGING_FILE}\" ] } ] }"
    if [ -e "$PIPELINE_LOG_CONF_DIR/$PIPELINE_LOG_CONF_FILENAME" ]; then
        rm -f "PIPELINE_LOG_CONF_DIR/$PIPELINE_LOG_CONF_FILENAME"
    fi
    echo -e "$PIPELINE_LOG_CONF_TEMPLATE" > "$PIPELINE_LOG_CONF_DIR/$PIPELINE_LOG_CONF_FILENAME"
    cat $PIPELINE_LOG_CONF_DIR/$PIPELINE_LOG_CONF_FILENAME  
    RC=$?
    if [ $RC -ne 0 ]; then
        debugme echo "Log init failed, could not create ${PIPELINE_LOG_CONF_FILENAME} file, rc = $RC"
        return 15
    fi

    # alternative solusion whithout restart service
    # Multi-tenant coniguation files
    if [ -e "$PIPELINE_LOG_CONF_DIR/multitenant.conf" ]; then
        rm -f "PIPELINE_LOG_CONF_DIR/multitenant.conf"
    fi
    echo -e "{" >> $PIPELINE_LOG_CONF_DIR/multitenant.conf
    echo -e "   # The multi-tenant section defines the owner of the log data" >> $PIPELINE_LOG_CONF_DIR/multitenant.conf
    echo -e "   # in a multi-tenant environment" >> $PIPELINE_LOG_CONF_DIR/multitenant.conf
    echo -e "   # This file is generated from the /etc/init/mt-logstash-forwarder.conf" >> $PIPELINE_LOG_CONF_DIR/multitenant.conf
    echo -e "   # upstart script" >> $PIPELINE_LOG_CONF_DIR/multitenant.conf
    echo -e "   \"multitenant\": {" >> $PIPELINE_LOG_CONF_DIR/multitenant.conf
    echo -e "       # Tell the tenant_id, password and other keypair values to insert" >> $PIPELINE_LOG_CONF_DIR/multitenant.conf
    echo -e "       \"tenant_id\": \"${LOG_SPACE_ID}\"," >> $PIPELINE_LOG_CONF_DIR/multitenant.conf
    echo -e "       \"password\" : \"${LOG_LOGGING_TOKEN}\"," >> $PIPELINE_LOG_CONF_DIR/multitenant.conf
    echo -e "       \"inserted_keypairs\" : {" >> $PIPELINE_LOG_CONF_DIR/multitenant.conf
    echo -e "           \"stack_id\" : \"${BMIX_ORG}\"," >> $PIPELINE_LOG_CONF_DIR/multitenant.conf
    echo -e "           \"instance_id\" : \"${BMIX_USER}\"" >> $PIPELINE_LOG_CONF_DIR/multitenant.conf
    echo -e "       }" >> $PIPELINE_LOG_CONF_DIR/multitenant.conf
    echo -e "   }" >> $PIPELINE_LOG_CONF_DIR/multitenant.conf
    echo -e "}" >> $PIPELINE_LOG_CONF_DIR/multitenant.conf
    cat $PIPELINE_LOG_CONF_DIR/multitenant.conf    
    RC=$?
    if [ $RC -ne 0 ]; then
        debugme echo "Log init failed, could not create multitenant.conf file, rc = $RC"
        return 16
    fi

    # Network coniguation files
    echo -e "{" >> $PIPELINE_LOG_CONF_DIR/network.conf
    echo -e "   # The network section covers network configuration" >> $PIPELINE_LOG_CONF_DIR/network.conf
    echo -e "   # This file is generated from the /etc/init/mt-logstash-forwarder.conf" >> $PIPELINE_LOG_CONF_DIR/network.conf
    echo -e "   # upstart script" >> $PIPELINE_LOG_CONF_DIR/network.conf
    echo -e "   \"network\": {" >> $PIPELINE_LOG_CONF_DIR/network.conf
    echo -e "       # A list of downstream servers listening for our messages." >> $PIPELINE_LOG_CONF_DIR/network.conf
    echo -e "       # logstash-forwarder will pick one at random and only switch if" >> $PIPELINE_LOG_CONF_DIR/network.conf
    echo -e "       # the selected one appears to be dead or unresponsive" >> $PIPELINE_LOG_CONF_DIR/network.conf
    echo -e "       \"servers\": [ \"${BMIX_TARGET_PREFIX}\" ]," >> $PIPELINE_LOG_CONF_DIR/network.conf
    echo -e "       # Network timeout in seconds. This is most important for" >> $PIPELINE_LOG_CONF_DIR/network.conf
    echo -e "       # logstash-forwarder determining whether to stop waiting for an" >> $PIPELINE_LOG_CONF_DIR/network.conf
    echo -e "       # acknowledgement from the downstream server. If an timeout is reached," >> $PIPELINE_LOG_CONF_DIR/network.conf
    echo -e "       # logstash-forwarder will assume the connection or server is bad and" >> $PIPELINE_LOG_CONF_DIR/network.conf
    echo -e "       # will connect to a server chosen at random from the servers list." >> $PIPELINE_LOG_CONF_DIR/network.conf
    echo -e "       \"timeout\": 15" >> $PIPELINE_LOG_CONF_DIR/network.conf
    echo -e "   }" >> $PIPELINE_LOG_CONF_DIR/network.conf
    echo -e "}" >> $PIPELINE_LOG_CONF_DIR/network.conf
    cat $PIPELINE_LOG_CONF_DIR/multitenant.conf    
    RC=$?
    if [ $RC -ne 0 ]; then
        debugme echo "Log init failed, could not create network.conf file, rc = $RC"
        return 17
    fi

    # Run the application in the foreground - output goes to stdout 
    # which the supervisord will redirect to a specified file.
    
    /opt/mt-logstash-forwarder/bin/mt-logstash-forwarder -config ${EXT_DIR}/conf.d -spool-size 100 -quiet true 2> /dev/null &
    RC=$?
    if [ $RC -ne 0 ]; then
        debugme echo "Log init failed, could not start mt-logstash-forwarder service, rc = $RC"
        return 18
    fi

    # restart forwarder to pick up the config changes
#    debugme echo "Restart mt-logstash-forwarder service"
#    sudo service mt-logstash-forwarder restart
#    RC=$?
#    if [ $RC -ne 0 ]; then
#        debugme echo "Log init failed, could not restart mt-logstash-forwarder service, rc = $RC"
#        return 19
#    fi
    
    # flag logging enabled for other extensions to use
    debugme echo "Logging setup and enabled"
    export LOGMET_LOGGING_ENABLED=1
    return 0
}

DEBUGGING="DEBUGGING_LEVEL"
INFO="INFO_LEVEL"
SUCCESSFUL="SUCCESSFUL_LEVEL"
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
    elif [ "$SUCCESSFUL" == "$MSG_TYPE" ]; then
        shift
        local pre="${green}"
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
            L_MSG=`echo $L_MSG | sed "s/\"/'/g"`
            echo "{\"@timestamp\": \"${timestamp}\", \"loglevel\": \"${MSG_LEVEL}\", \"module\": \"pipeline\", \"message\": \"$L_MSG\"}" >> "$PIPELINE_LOGGING_FILE"
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
            echo -e "${label_color}There was ${ERROR_COUNT} error message recorded during execution:${no_color}"
        else
            echo -e "${label_color}There were ${ERROR_COUNT} error messages recorded during execution:${no_color}"
        fi
        cat "${ERROR_LOG_FILE}"
    fi
    #No output if no errors were recorded
    
}

###################################################################
# get the line without the color code
###################################################################
remove_red_color_code() {
    local STR=$1

    # get the converted string with the special characters
    STR=`echo -e "$STR"`

    # strip all ANSI color codes
    STR=`echo $STR | sed -r 's/\x1B\[[0-9;]*[mK]//g'`

    # dump the un-coded string
    echo -e "$STR"
}

###################################################################
# get the error.log information
###################################################################
get_error_info() {
    local ERROR_LOG_INFO=""
    local ERROR_LOG_FILE="${EXT_DIR}/errors.log"
    local ERROR_LOG_TITLE=""
    if [ -f "$ERROR_LOG_FILE" ]; then
        ERROR_COUNT=`wc "${ERROR_LOG_FILE}" | awk '{print $1}'` 
        if [ ${ERROR_COUNT} -eq 1 ]; then
            ERROR_LOG_TITLE="\\nThere was ${ERROR_COUNT} error message recorded during execution:"
        else
            ERROR_LOG_TITLE="\\nThere were ${ERROR_COUNT} error messages recorded during execution:"
        fi
        ERROR_LOG_INFO=$(cat "${ERROR_LOG_FILE}" | while read line; do echo "\\n"; echo -n $(remove_red_color_code "$line"); done)
    fi
    echo $ERROR_LOG_TITLE $ERROR_LOG_INFO
}

# begin main execution sequence

export -f setup_met_logging
export -f log_and_echo
export -f print_errors
export -f remove_red_color_code
export -f get_error_info
# export message types for log_and_echo
# ERRORs will be collected
export DEBUGGING
export INFO
export SUCCESSFUL
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

