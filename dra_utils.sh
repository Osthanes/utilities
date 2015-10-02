#!/bin/bash

#********************************************************************************
# Copyright 2014 IBM
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

###############################
# get project key             #
###############################
# Register your project with DRA Application, and record the returned project key
get_dra_prject_key() {
    if [ -n "${IDS_PROJECT_NAME}" ]; then 
        debugme echo -e "get DRA project key for projectName '${IDS_PROJECT_NAME}'"
    else
        debugme echo -e "Get DRA project key failed. ProjectName is missing."
        return 1
    fi 

    # set project.json and dra-response.info files
    local PROJECT_FILE="project.json"
    local RESPONCE_FILE="dra-response.info"
    if [ -e "$PROJECT_FILE" ]; then
        rm -f "$PROJECT_FILE"
    fi
    if [ -e "$RESPONCE_FILE" ]; then
        rm -f "$RESPONCE_FILE"
    fi
    local PROJECT_FILE_INFO="{\"projectName\": \"${IDS_PROJECT_NAME}\"}"
    echo -e "$PROJECT_FILE_INFO" > "$PROJECT_FILE"

    # get project key
    local DRA_URL="http://da.oneibmcloud.com/api/v1/project"
    debugme echo -e "Fetching DRA project key for $IDS_PROJECT_NAME IDS project" 
    debugme cat "$PROJECT_FILE"
    debugme echo -e "curl -k --silent -H "Content-Type: application/json" -X POST -d @$PROJECT_FILE $DRA_URL"
    curl -k --silent -H "Content-Type: application/json" -X POST -d @$PROJECT_FILE $DRA_URL > "$RESPONCE_FILE"
    local RC=$?
    debugme cat "$RESPONCE_FILE"
    rm -f "$PROJECT_FILE"
    if [ $RC == 0 ] && [ $(grep -ci "projectkey" "$RESPONCE_FILE") -ne 0 ]; then
        local PROJECT_KEY_INFO=$(cat "$RESPONCE_FILE")
        export DRA_PROJECT_KEY=$(echo $PROJECT_KEY_INFO | sed 's/.*"projectkey":"//' | sed 's/"}]//g')
        if [ -n "$DRA_PROJECT_KEY" ]; then
            debugme echo -e "Successfully get the project key ${DRA_PROJECT_KEY}"
        else
            debugme echo -e "Failed to get project key"
            return 1
        fi
        rm -f "$RESPONCE_FILE"
    else
        rm -f "$RESPONCE_FILE"
        # unable to curl DRA project key, fail out
        debugme echo -e "get DRA project key failed, could not get DRA project key, rc = $RC"
        return 1
    fi
    return 0
}

###############################
# add criterial to DRA       #
###############################
add_criterial_rule_to_dra() {
    local CRITERIAL_FILE=$1
    if [ -n "${CRITERIAL_FILE}" ]; then
        debugme echo -e "Set criterial rule to DRA in file '${CRITERIAL_FILE}'"
    else
        debugme echo -e "Set criterial rule to DRA failed. Criterial rule file is missing."
        return 1
    fi 

    # set the criterial file
    local RESPONCE_FILE="dra-response.info"
    if [ -e "$RESPONCE_FILE" ]; then
        rm -f "$RESPONCE_FILE"
    fi
    local DRA_ADD_CRITERIAL_URL="http://da.oneibmcloud.com/api/v1/criteria"
    debugme echo -e "Fetching criterial rules to DRA for $CRITERIAL_FILE."
    debugme echo -e "$(cat $CRITERIAL_FILE)"
    debugme echo -e "curl -k --silent -H Content-Type: application/json -H projectKey:$DRA_PROJECT_KEY -X POST -d @$CRITERIAL_FILE $DRA_ADD_CRITERIAL_URL"
    curl -k --silent -H Content-Type: application/json -H projectKey:$DRA_PROJECT_KEY -X POST -d @$CRITERIAL_FILE $DRA_ADD_CRITERIAL_URL > "$RESPONCE_FILE"
    local RC=$?
    debugme cat "$RESPONCE_FILE"
    echo ""
    if [ $RC == 0 ]; then
        local RESPONCE=$(cat "$RESPONCE_FILE")
        if [ -n "$RESPONSE" ]; then
            echo $RESPONSE | grep "Invalid"
            RC=$?
            if [ $RC -eq 0 ]; then
                return 1
            else
                debugme echo -e "Successfully sent the criterial rules file $CRITERIAL_FILE to DRA"
           fi
        fi
    else
        debugme echo -e "Failed to send criterial rule file $CRITERIAL_FILE to DRA."
        return 1
    fi
    return 0
}

###############################
# add result to DRA       #
###############################
add_result_rule_to_dra() {
    local RULE_FILE=$1
    if [ -n "${RULE_FILE}" ]; then
        debugme echo -e "Set result rule to DRA in file '${RULE_FILE}'"
    else
        debugme echo -e "Set result rule to DRA failed. Result rule file is missing."
        return 1
    fi 

    # set the criterial file
    local RESPONCE_FILE="dra-response.info"
    if [ -e "$RESPONCE_FILE" ]; then
        rm -f "$RESPONCE_FILE"
    fi
    local DRA_URL="http://da.oneibmcloud.com/api/v1/event"
    debugme echo -e "Fetching result rules to DRA for $RULE_FILE."
    debugme echo -e "$(cat $RULE_FILE)"
    debugme echo -e "curl -k --silent -H Content-Type: application/json -H projectKey:$DRA_PROJECT_KEY -X POST -d @$RULE_FILE $DRA_URL"
    curl -k --silent -H Content-Type: application/json -H projectKey:$DRA_PROJECT_KEY -X POST -d @$RULE_FILE $DRA_URL > "$RESPONCE_FILE"
    local RC=$?
    debugme cat "$RESPONCE_FILE"
    echo ""
    if [ $RC == 0 ]; then
        local RESPONCE=$(cat "$RESPONCE_FILE")
        if [ -n "$RESPONSE" ]; then
            echo $RESPONSE | grep "Invalid"
            RC=$?
            if [ $RC -eq 0 ]; then
                return 1
            else
                debugme echo -e "Successfully sent the result rule file $CRITERIAL_FILE to DRA."
           fi
        fi
    else
        debugme echo -e "Failed to send result file $CRITERIAL_FILE to DRA."
        return 1
    fi
    return 0
}

###############################
# Setup grunt idra            #
###############################
setup_grunt_idra() {
    debugme echo -e "npm install -g grunt"
    npm install -g grunt &> /dev/null
    RC=$?
    if [ $RC -ne 0 ]; then
        debugme echo -e "Failed to setup_grunt_idra. Could not install grunt"
        return 1
    fi 

    debugme echo -e "npm install -g grunt-cli"
    npm install -g grunt-cli &> /dev/null
    RC=$?
    if [ $RC -ne 0 ]; then
        debugme echo -e "Failed to setup_grunt_idra. Could not install grunt-cli"
        return 1
    fi 

    npm install grunt-idra &> /dev/null
    RC=$?
    if [ $RC -ne 0 ]; then
        debugme echo -e "Failed to setup_grunt_idra. Could not install node grunt-idra"
        return 1
    fi 

    return 0
}

###############################
# Initialize iDRA plugin      #
###############################
init_dra() {
    # check -isDRAEnabled
    debugme echo -e "grunt --gruntfile=node_modules/grunt-idra/idra.js -init=$DRA_PROJECT_KEY"
    local RESPONSE="$(grunt --gruntfile=node_modules/grunt-idra/idra.js -init=$DRA_PROJECT_KEY)"
    local RC=$?
    debugme "$RESPONSE"
    if [ $RC -ne 0 ]; then
        debugme echo -e "Failed to init_dra. init DRA return error code ${RESULT}"
        return 1
    fi 

    if [ -n "$RESPONSE" ]; then
        echo $RESPONSE | grep "successfully"
        RC=$?
        if [ $RC -eq 0 ]; then
            return 0
        else
            return 1
       fi
    else
        debugme echo -e "Failed to init_dra. init DRA return empty response"
        return 1        
    fi
}

###############################
# check if the DRA is enabeld #
###############################
check_dra_enabled() {
    # check -isDRAEnabled
    local RESPONSE="$(grunt --gruntfile=node_modules/grunt-idra/idra.js -isDRAEnabled)"
    local RC=$?
    if [ $RC -ne 0 ]; then
        debugme echo -e "Failed to setup_grunt_idra. Check for isDRAEnabled return error code ${RC}"
        return 1
    fi 

    if [ -n "$RESPONSE" ]; then
        local ENABLED_RESPONSE=$(echo $RESPONSE | grep "enabled" | awk '{print $6}' | sed 's/.*"enabled"://' | sed 's/}//g')
        if [ "$ENABLED_RESPONSE" == "true" ]; then
            debugme echo -e "The DRA is enabled"
            return 0
        else
            debugme echo -e "$RESPONSE"
            debugme echo -e "The DRA is not enabled"
            return 1
       fi
    else
        debugme echo -e "Failed to setup_grunt_idra. Check for isDRAEnabled return empty response"
        return 1
    fi 

}

###############################
# Setup DRA for build  stage  #
###############################
setup_dra_build(){
    # setup the grunt idra
    setup_grunt_idra
    local RC=$?
    if [ $RC -ne 0 ]; then
        debugme echo -e "Failed to setup_dra_build. setup_grunt_idra return error code ${RC}"
        return 1
    fi 

    # run grunt-idra -init
    grunt --gruntfile=node_modules/grunt-idra/idra.js -init=$DRA_PROJECT_KEY
    RC=$?
    if [ $RC -ne 0 ]; then
        debugme echo -e "Failed to setup_grunt_idra. init dra key return error code ${RC}"
        return 1
    fi 

    # check -isDRAEnabled
    check_dra_enabled
    RC=$?
    if [ $RC -ne 0 ]; then
        debugme echo -e "Failed to setup_dra_build. check_dra_enabled return error code ${RC}"
        return 1
    fi 
    return 0
}

###############################
# Setup DRA for deploy stage  #
###############################
setup_dra_deploy(){
    local CRITERIA_NAME=$1
    if [ -n "${CRITERIA_NAME}" ]; then
        debugme echo -e "setup_dra_deploy for DRA for decision criteria name '${CRITERIA_NAME}'"
    else
        debugme echo -e "setup_dra_deploy failed. CRITERIA_NAME is missing."
        return 1
    fi 
    # setup the grunt idra
    setup_grunt_idra
    local RC=$?
    if [ $RC -ne 0 ]; then
        debugme echo -e "Failed to setup_dra_deploy. setup_grunt_idra return error code ${RC}"
        return 1
    fi 

    # set the decision criteria name
    grunt --gruntfile=node_modules/grunt-idra/idra.js -decision=$CRITERIA_NAME
    RC=$?
    if [ $RC -ne 0 ]; then
        debugme echo -e "Failed to check_dra_enabled. check_dra_enabled return error code ${RC}"
        return 1
    fi 
    return 0
}

###############################
# Set Event Type to DRA       #
###############################
set_event_type(){
    local EVENT_TYPE=$1
    if [ -n "${EVENT_TYPE}" ]; then
        debugme echo -e "EVENT_TYPE is '${EVENT_TYPE}'"
    else
        debugme echo -e "EVENT_TYPE is missing."
        return 1
    fi 

    # set the decision criteria name
    grunt --gruntfile=node_modules/grunt-idra/idra.js -eventType=$EVENT_TYPE
    local RC=$?
    if [ $RC -ne 0 ]; then
        debugme echo -e "Failed to set event type ${EVENT_TYPE} with return error code ${RC}"
        return 1
    fi 
    return 0
}

###############################
# Setup DRA                   #
###############################
setup_dra(){
    local CRITERIAL_NAME=$1
    if [ -n "${CRITERIAL_NAME}" ]; then
        debugme echo -e "Setup DRA for criterial name '${CRITERIAL_NAME}'"
    else
        debugme echo -e "Failed to setup_dra. criterial name is missing."
        return 1
    fi     
    setup_grunt_idra
    RESULT=$?
    if [ $RESULT -eq 0 ]; then
        # get the DRA Project Key
        get_dra_prject_key
        RESULT=$?
        if [ $RESULT -eq 0 ]; then
            log_and_echo "DRA project key for projectName '${IDS_PROJECT_NAME}' is '${DRA_PROJECT_KEY}"
            # grunt-idra -init
            init_dra
            RESULT=$?
            if [ $RESULT -eq 0 ]; then
                # check DRA is enabled
                check_dra_enabled
                RESULT=$?
                if [ $RESULT -eq 0 ]; then
                    # add criterial for DRA
                    add_criterial_rule_to_dra "${CRITERIAL_NAME}.json"
                    RESULT=$?
                    if [ $RESULT -eq 0 ]; then
                        log_and_echo "DRA project key for projectName '${IDS_PROJECT_NAME}' is '${DRA_PROJECT_KEY}"
                        export DRA_ENABLED=0
                        return 0
                    else
                        log_and_echo "$WARN" "Failed to add DRA criterial file ${CRITERIAL_FILE} with return error code ${RESULT}. Could not Add Dynamic Risk Analytics."
                        return 2
                    fi
                else 
                    debugme "$WARN" "DRA is not enabled with return error code ${RESULT}. Could not Add Dynamic Risk Analytics."
                    return 1
                fi
            else
                debugme "$WARN" "Failed to init DRA with return error code ${RESULT}. Could not Add Dynamic Risk Analytics."
                return 1
            fi 
        else
            debugme echo -e "Failed to get DRA project key with return error code ${RESULT}. Could not Add Dynamic Risk Analytics."
            return 1
        fi
    else
        debugme echo -e "Failed to setup grunt_idra with return error code ${RESULT}. Could not Add Dynamic Risk Analytics."
        return 1
    fi
}

export -f get_dra_prject_key
export -f add_criterial_for_dra
export -f setup_grunt_idra
export -f init_dra
export -f check_dra_enabled
export -f setup_dra_build
export -f setup_dra_deploy
export -f set_event_type
export -f setup_dra

export DRA_PROJECT_KEY

