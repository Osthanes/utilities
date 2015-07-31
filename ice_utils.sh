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

###########################################################
# Login to Container Service                              #
# Using ice login command  with bluemix api key           #
###########################################################
ice_login_with_api_key() {
    local API_KEY=$1
    if [ -z "${API_KEY}" ]; then
        echo -e "${red}Expected API_KEY to be passed into ice_login_with_api_key ${no_color}"
        return 1
    fi
    local RC=0
    local retries=0
    while [ $retries -lt 5 ]; do
        debugme echo "login command: ice $ICE_ARGS login --key ${API_KEY}"
        #ice $ICE_ARGS login --key ${API_KEY} --host ${CCS_API_HOST} --registry ${CCS_REGISTRY_HOST} --api ${BLUEMIX_API_HOST} 
        ice $ICE_ARGS login --key ${API_KEY} 2> /dev/null
        RC=$?
        if [ ${RC} -eq 0 ]; then
            break
        fi
        echo -e "${label_color}Failed to login to IBM Container Service. Sleep 20 sec and try again.${no_color}"
        sleep 20
        retries=$(( $retries + 1 ))   
    done
    return $RC
}

###########################################################
# Login to Container Service                              #
# Using ice login command  with bluemix user              #
###########################################################
ice_login_with_bluemix_user() {
    local CCS_API_HOST=$1
    local CCS_REGISTRY_HOST=$2
    local BLUEMIX_API_HOST=$3
    local BLUEMIX_USER=$4
    local BLUEMIX_PASSWORD=$5
    local BLUEMIX_ORG=$6
    local BLUEMIX_SPACE=$7
    if [ -z "${CCS_API_HOST}" ]; then
        echo -e "${red}Expected CCS_API_HOST to be passed into ice_login_with_bluemix_user ${no_color}"
        return 1
    fi
    if [ -z "${CCS_REGISTRY_HOST}" ]; then
        echo -e "${red}Expected CCS_REGISTRY_HOST to be passed into ice_login_with_bluemix_user ${no_color}"
        return 1
    fi
    if [ -z "${BLUEMIX_API_HOST}" ]; then
        echo -e "${red}Expected BLUEMIX_API_HOST to be passed into ice_login_with_bluemix_user ${no_color}"
        return 1
    fi
    if [ -z "${BLUEMIX_USER}" ]; then 
        echo -e "${red}Expected BLUEMIX_USER to be passed into ice_login_with_bluemix_user ${no_color}"
        return 1
    fi 
    if [ -z "${BLUEMIX_PASSWORD}" ]; then 
        echo -e "${red}Expected BLUEMIX_PASSWORD to be passed into ice_login_with_bluemix_user ${no_color}"
        return 1
    fi 
    if [ -z "${BLUEMIX_ORG}" ]; then 
        echo -e "${red}Expected BLUEMIX_ORG to be passed into ice_login_with_bluemix_user ${no_color}"
        return 1
    fi 
    if [ -z "${BLUEMIX_SPACE}" ]; then
        echo -e "${red}Expected BLUEMIX_SPACE to be passed into ice_login_with_bluemix_user ${no_color}"
        return 1
    fi 
    local RC=0
    local retries=0
    while [ $retries -lt 5 ]; do 
        debugme echo "login command: ice $ICE_ARGS login --cf --host ${CCS_API_HOST} --registry ${CCS_REGISTRY_HOST} --api ${BLUEMIX_API_HOST} --user ${BLUEMIX_USER} --psswd ${BLUEMIX_PASSWORD} --org ${BLUEMIX_ORG} --space ${BLUEMIX_SPACE}"
        ice $ICE_ARGS login --cf --host ${CCS_API_HOST} --registry ${CCS_REGISTRY_HOST} --api ${BLUEMIX_API_HOST} --user ${BLUEMIX_USER} --psswd ${BLUEMIX_PASSWORD} --org ${BLUEMIX_ORG} --space ${BLUEMIX_SPACE} 2> /dev/null
        RC=$?
        if [ ${RC} -eq 0 ] || [ ${RC} -eq 2 ]; then
            break
        fi
        echo -e "${label_color}Failed to login to IBM Container Service. Sleep 20 sec and try again.${no_color}"
        sleep 20
        retries=$(( $retries + 1 ))   
    done
    return $RC
}

###########################################################
# Get Container information
# Using ice info command
###########################################################
ice_info() {
    local RC=0
    local retries=0
    while [ $retries -lt 5 ]; do
        debugme echo "ice info command: ice ICE_ARGS info"
        local ICEINFO=$(ice info 2>/dev/null)
        echo "$ICEINFO" > iceinfo.log 2> /dev/null
        RC=$?
        debugme echo "$ICEINFO"
        if [ ${RC} -eq 0 ]; then
            break
        fi
        echo -e "${label_color}ice info did not return successfully. Sleep 20 sec and try again.${no_color}"
        sleep 20
        retries=$(( $retries + 1 ))
        rm -f iceinfo.log 
    done
    return $RC
}

###########################################################
# Get list of the container images  
# Using ice images command           
###########################################################
ice_images() {
    local RC=0
    local retries=0
    while [ $retries -lt 5 ]; do
        debugme echo "ice images command: ice ICE_ARGS images"
        ice images &> /dev/null
        RC=$?
        if [ ${RC} -eq 0 ]; then
            break
        else
            echo -e "${label_color}ice images did not return successfully. Sleep 20 sec and try again.${no_color}"
        fi
        sleep 20
        retries=$(( $retries + 1 )) 
    done  
    return $RC
}

###########################################################
# build the Container image             
# Using ice build command
###########################################################
ice_build_image() {
    local USE_CACHED_LAYERS=$1
    local FULL_REPOSITORY_NAME=$2
    local WORKSPACE=$3
    if [ -z "${FULL_REPOSITORY_NAME}" ]; then
        echo -e "${red}Expected FULL_REPOSITORY_NAME to be passed into ice_build_image ${no_color}"
        return 1
    fi
    if [ -z "${WORKSPACE}" ]; then
        echo -e "${red}Expected WORKSPACE to be passed into ice_build_image ${no_color}"
        return 1
    fi
    local RC=0
    local retries=0
    local CHACHE_OPTION=""
    local PULL_OPTION=""
    local BUILD_COMMAND=""
    if [ -n "$USE_CACHED_LAYERS" ] && [ "$USE_CACHED_LAYERS" == "true" ]; then
        PULL_OPTION="--pull"
    else
        CHACHE_OPTION="--no-cache"
    fi
    while [ $retries -lt 5 ]; do
        BUILD_COMMAND="ice $ICE_ARGS build ${CHACHE_OPTION} ${PULL_OPTION} --tag ${FULL_REPOSITORY_NAME} ${WORKSPACE}"
        echo "Build command: ${BUILD_COMMAND}"
        ${BUILD_COMMAND}
        RC=$?
        if [ ${RC} -eq 0 ]; then
            break
        fi
        echo -e "${label_color}Failed to build IBM Container image. Sleep 20 sec and try again.${no_color}"
        sleep 20
        retries=$(( $retries + 1 ))   
    done
    return $RC
}

###########################################################
# Rmeove Container image 
# Using ice rmi command
###########################################################
ice_rmi() {
    local IMAGE_NAME=$1
    if [ -z "${IMAGE_NAME}" ]; then
        echo -e "${red}Expected IMAGE_NAME to be passed into ice_rmi ${no_color}"
        return 1
    fi
    local RC=0
    local retries=0
    local RESPONSE=""
    while [ $retries -lt 5 ]; do
        debugme echo "ice rmi command: ice $ICE_ARGS rmi ${IMAGE_NAME}"
        RESPONSE=$(ice $ICE_ARGS rmi ${IMAGE_NAME} 2> /dev/null)
        RC=$?
        if [ ${RC} -eq 0 ]; then
            break
        else
            echo -e "${label_color}ice rmi did not return successfully. Sleep 20 sec and try again.${no_color}"
        fi
        sleep 20
        retries=$(( $retries + 1 )) 
    done
    export RET_RESPONCE=${RESPONSE}
    return $RC
}

###########################################################
# Container inspect images 
# Using ice inspect images command
###########################################################
ice_inspect_images() {
    local RC=0
    local retries=0
    local RESPONSE=""
    while [ $retries -lt 5 ]; do
        debugme echo "ice inspect images command: ice $ICE_ARGS inspect images"
        ice inspect images > inspect.log 2> /dev/null
        RC=$?
        if [ ${RC} -eq 0 ]; then
            break
        else
            echo -e "${label_color}ice inspect images did not return successfully. Sleep 20 sec and try again.${no_color}"
        fi
        sleep 20
        retries=$(( $retries + 1 )) 
    done
    return $RC
}

###########################################################
# Ice command retry function with not output
# 
###########################################################
ice_retry(){
    local RC=0
    local retries=0
    local iceparms="$*"
    debugme echo "ice command: ice ${iceparms}"
    while [ $retries -lt 5 ]; do
        ice $iceparms
        RC=$?
        if [ ${RC} -eq 0 ]; then
            break
        fi
        echo -e "${label_color}\"ice ${iceparms}\" did not return successfully. Sleep 20 sec and try again.${no_color}"
        sleep 20
        retries=$(( $retries + 1 ))
    done
    return $RC
}

###########################################################
# Ice command retry function with save output
# in iceretry.log file
###########################################################
ice_retry_save_output(){
    local RC=0
    local retries=0
    local iceparms="$*"
    debugme echo "ice command: ice ${iceparms}"
    while [ $retries -lt 5 ]; do
        ice $iceparms > iceretry.log
        RC=$?
        if [ ${RC} -eq 0 ]; then
            break
        fi
        debugme cat iceretry.log
        echo -e "${label_color}\"ice ${iceparms}\" did not return successfully. Sleep 20 sec and try again.${no_color}"
        sleep 20
        retries=$(( $retries + 1 ))
    done
    return $RC
}

################################
# Print EnablementInfo         #
################################
printEnablementInfo() {
    echo -e "${label_color}No namespace has been defined for this user ${no_color}"
    echo -e "Please check the following: "
    echo -e "   - Login to Bluemix ( https://console.ng.bluemix.net )"
    echo -e "   - Select the 'IBM Containers' icon from the Dashboard" 
    echo -e "   - Select 'Create a Container'"
    echo -e "Or using the ICE command line: "
    echo -e "   - ice login -a api.ng.bluemix.net -H containers-api.ng.bluemix.net -R registry.ng.bluemix.net"
    echo -e "   - ${label_color}ice namespace set [your-desired-namespace] ${no_color}"
}

###########################################################
# Login to Container Service                              #
# Using ice login command  with bluemix api key           #
###########################################################
ice_login_check() {
    local RC=0
    local retries=0
    mkdir -p ~/.ice
    debugme cat "${EXT_DIR}/${ICE_CFG}"
    cp ${EXT_DIR}/${ICE_CFG} ~/.ice/ice-cfg.ini
    debugme cat ~/.ice/ice-cfg.ini
    debugme echo "config.json:"
    debugme cat /home/jenkins/.cf/config.json | cut -c1-2
    debugme cat /home/jenkins/.cf/config.json | cut -c3-
    debugme echo "testing ice login via ice info command"
    ice_retry info 2>/dev/null
    RC=$?
    if [ ${RC} -eq 0 ]; then
        ice_retry images 2>/dev/null
        RC=$?
    fi
    return $RC
}

################################
# Get trimmed value            #
################################
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

#####################################################
# get targeting information from config.json file   #
#####################################################
get_targeting_information() {
    local ORG_FLAG=false
    local SPACE_FLAG=false
    local local_val=""
    while read -r line || [[ -n $line ]]; do 
        if [[ $line == *"\"AccessToken\":"* ]]; then
            local_val=$(get_trimmed_value "${line#*:}")
            if [ "${local_val}x" != "x" ]; then
                if [ -z "$BLUEMIX_ACCESS_TOKEN" ]; then
                    export BLUEMIX_ACCESS_TOKEN=$local_val
                else
                    debugme echo "failed to get BLUEMIX_ACCESS_TOKEN" 
                fi
            fi
        elif [[ $line == *"\"UaaEndpoint\":"* ]]; then
            local_val=$(get_trimmed_value "${line#*:}")
            if [ "${local_val}x" != "x" ]; then
                if [ -z "$UAA_END_POINT_URL" ]; then
                    export UAA_END_POINT_URL=$local_val
                else
                    debugme echo "failed to get UAA_END_POINT_URL" 
                fi
            fi
        elif [[ $line == *"\"OrganizationFields\":"* ]]; then
            ORG_FLAG=true
        elif [[ $line == *"\"SpaceFields\":"* ]]; then
            SPACE_FLAG=true
        elif [[ $line == *"\"Name\":"* ]] && [ "$ORG_FLAG" == "true" ]; then
            local_val=$(get_trimmed_value "${line#*:}")
            if [ "${local_val}x" != "x" ]; then
                if [ -z "$BLUEMIX_ORG" ]; then
                    export BLUEMIX_ORG=$local_val
                else
                    debugme echo "failed to get BLUEMIX_ORG" 
                fi
            fi
            ORG_FLAG=false
        elif [[ $line == *"\"Name\":"* ]] && [ "$SPACE_FLAG" == "true" ]; then
            local_val=$(get_trimmed_value "${line#*:}")
            if [ "${local_val}x" != "x" ]; then
                if [ -z "$BLUEMIX_SPACE" ]; then
                    export BLUEMIX_SPACE=$local_val
                else
                    debugme echo "failed to get BLUEMIX_SPACE" 
                fi
            fi
            SPACE_FLAG=false
    fi
    done <~/.cf/config.json
    if [ -z "$BLUEMIX_USER" ]; then
        local user_id_flag=0
        USER_INFO=$(curl  -k --silent -H "Content-type: application/json" -H "Authorization: $BLUEMIX_ACCESS_TOKEN" -X GET $UAA_END_POINT_URL/userinfo)
        RC=$?
        if [ $RC -eq 0 ]; then
            export BLUEMIX_USER=$(echo $USER_INFO | awk -F'name":' '{print $2;}' | awk -F'"' '{print $2;}')
            if [ -z "$BLUEMIX_USER" ]; then
                debugme echo "failed to get BLUEMIX_USER"
            fi
        else
            debugme echo "failed to get BLUEMIX_USER"           
        fi
    fi
    return 0
}

##########################################
# login_using_bluemix_user_password      #
##########################################
login_using_bluemix_user_password(){
    if [ -z "$BLUEMIX_USER" ]; then 
        echo -e "${red} In order to login with ice login command, the Bluemix user id is required ${no_color}" | tee -a "$ERROR_LOG_FILE"
        echo -e "${red} Please set BLUEMIX_USER on environment ${no_color}" | tee -a "$ERROR_LOG_FILE"
        ${EXT_DIR}/utilities/sendMessage.sh -l bad -m "Failed to get BLUEMIX_USER ID. $(get_error_info)"
        ${EXT_DIR}/print_help.sh
        return 1
    fi 
    if [ -z "$BLUEMIX_PASSWORD" ]; then 
        echo -e "${red} In order to login with ice login command, the Bluemix password is required ${no_color}" | tee -a "$ERROR_LOG_FILE"
        echo -e "${red} Please set BLUEMIX_PASSWORD as an environment property environment ${no_color}" | tee -a "$ERROR_LOG_FILE"
        ${EXT_DIR}/utilities/sendMessage.sh -l bad -m "Failed to get BLUEMIX_PASSWORD. $(get_error_info)"
        ${EXT_DIR}/print_help.sh
        return 1
    fi 
    if [ -z "$BLUEMIX_ORG" ]; then 
        export BLUEMIX_ORG=$BLUEMIX_USER
        echo -e "${label_color} Using ${BLUEMIX_ORG} for Bluemix organization, please set BLUEMIX_ORG on the environment if you wish to change this. ${no_color} "
    fi 
    if [ -z "$BLUEMIX_SPACE" ]; then
        export BLUEMIX_SPACE="dev"
        echo -e "${label_color} Using ${BLUEMIX_SPACE} for Bluemix space, please set BLUEMIX_SPACE on the environment if you wish to change this. ${no_color} "
    fi 
    echo -e "${label_color}Logging on with Bluemix userid and Bluemix password${no_color}"
    echo "BLUEMIX_USER: ${BLUEMIX_USER}"
    echo "BLUEMIX_SPACE: ${BLUEMIX_SPACE}"
    echo "BLUEMIX_ORG: ${BLUEMIX_ORG}"
    echo "BLUEMIX_PASSWORD: xxxxx"
    echo ""
    ice_login_with_bluemix_user ${CCS_API_HOST} ${CCS_REGISTRY_HOST} ${BLUEMIX_API_HOST} ${BLUEMIX_USER} ${BLUEMIX_PASSWORD} ${BLUEMIX_ORG} ${BLUEMIX_SPACE} 2> /dev/null
    RC=$?
    if [ $RC -eq 0 ]; then
        echo -e "${label_color}Logged in into IBM Container Service using ice login command${no_color}"
        ice_login_check
        RC=$?
        if [ $RC -ne 0 ]; then
            echo -e "${red}ice info command failed with return code ${RC}. ${no_color}"
        fi
    elif [ $RC -eq 2 ]; then
        echo -e "${label_color}Logged in into IBM Container Service using ice login command returns error code ${RC}${no_color}"
        ice_login_check
        RC=$?
        if [ $RC -ne 0 ]; then
            echo -e "${red}ice info command failed with return code ${RC}. ${no_color}"
        fi
    else
        echo -e "${red}Failed to log in into IBM Container Service${no_color}. ice login command returns error code ${RC}" | tee -a "$ERROR_LOG_FILE"
    fi 
}
################################
# Login to Container Service   #
################################
login_to_container_service(){
    # set targeting information from config.json file
    if [ -f ~/.cf/config.json ]; then
        get_targeting_information
    fi
    # Check if we are already logged in via ice command 
    ice_login_check
    local RC=$?
    # check login result 
    if [ $RC -ne 0 ]; then
        echo -e "${label_color}Failed to access to IBM Container Service using credentials passed from IBM DevOps Services. 'ice info' command failed with return code ${RC}. ${no_color}"
        echo -e "${label_color}Trying to login with 'ice login' command using Bluemix userid and password and check again 'ice info' command. ${no_color}"
        if [ -n "$API_KEY" ]; then 
            echo -e "${label_color}Logging on with API_KEY${no_color}"
            ice_retry $ICE_ARGS login --key ${API_KEY} 2> /dev/null
            RC=$?
        else
            login_using_bluemix_user_password
            RC=$?
        fi
    else
        echo -e "${label_color}Successfully accessed into IBM Container Service using credentials passed from IBM DevOps Services ${no_color}"
    fi
    # check login result 
    if [ $RC -ne 0 ]; then
        echo -e "${red}Failed to accessed into IBM Container Service${no_color}" | tee -a "$ERROR_LOG_FILE"
        ${EXT_DIR}/print_help.sh
        ${EXT_DIR}/utilities/sendMessage.sh -l bad -m "Failed to login to IBM Container Service CLI. $(get_error_info)"
    else 
        echo -e "${green}Successfully accessed into IBM Containers Service${no_color}"
        ice info 2> /dev/null
    fi 
    return $RC
} 

########################
# Get Name Space       #
########################
get_name_space() {
    NAMESPACE=$(ice namespace get)
    RC=$?
    if [ $RC -eq 0 ]; then
        if [ -z $NAMESPACE ]; then
            log_and_echo "$ERROR" "Did not discover namespace using ice namespace get, but no error was returned"
            printEnablementInfo
            ${EXT_DIR}/print_help.sh
            ${EXT_DIR}/utilities/sendMessage.sh -l bad -m "Failed to discover namespace. $(get_error_info)"
            RC=1
        else
            export NAMESPACE=$NAMESPACE
        fi
    else 
        log_and_echo "$ERROR" "ice namespace get' returned an error"
        printEnablementInfo
        ${EXT_DIR}/print_help.sh    
        ${EXT_DIR}/utilities/sendMessage.sh -l bad -m "Failed to get namespace. $(get_error_info)"
    fi 
    return $RC
}

export -f ice_login_with_api_key
export -f ice_login_with_bluemix_user
export -f ice_login_check
export -f ice_info
export -f ice_images
export -f ice_build_image
export -f ice_rmi
export -f ice_inspect_images

export -f ice_retry
export -f ice_retry_save_output
export -f printEnablementInfo
export -f get_targeting_information
export -f get_trimmed_value
export -f login_using_bluemix_user_password
export -f login_to_container_service
export -f get_name_space

export RET_RESPONCE
export NAMESPACE
export BLUEMIX_ACCESS_TOKEN
export UAA_END_POINT_URL
export BLUEMIX_ORG
export BLUEMIX_SPACE
export BLUEMIX_USER
