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
    ice_info
    RC=$?
    if [ ${RC} -eq 0 ]; then
        ice_images
        RC=$?
    fi
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
        ice $ICE_ARGS info > iceinfo.log 2> /dev/null
        RC=$?
        debugme cat iceinfo.log 
        if [ ${RC} -eq 0 ]; then
            break
        fi
        echo -e "${label_color}ice info did not return successfully. Sleep 20 sec and try again.${no_color}"
        sleep 20
        retries=$(( $retries + 1 ))
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
    local WORKSPACE=$4
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
    if [ -z "${USE_CACHED_LAYERS}" && "${USE_CACHED_LAYERS}" == "true"]; then
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

export -f ice_login_with_api_key
export -f ice_login_with_bluemix_user
export -f ice_login_check
export -f ice_info
export -f ice_images
export -f ice_build_image
export -f ice_rmi
export -f ice_inspect_images

export RET_RESPONCE
