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
    local RESPONSE_FILE="dra-response.info"
    if [ -e "$PROJECT_FILE" ]; then
        rm -f "$PROJECT_FILE"
    fi
    if [ -e "$RESPONSE_FILE" ]; then
        rm -f "$RESPONSE_FILE"
    fi
    local PROJECT_FILE_INFO="{\"projectName\": \"${IDS_PROJECT_NAME}\"}"
    echo -e "$PROJECT_FILE_INFO" > "$PROJECT_FILE"

    # get project key
    local DRA_URL="http://da.oneibmcloud.com/api/v1/project"
    debugme echo -e "Fetching DRA project key for $IDS_PROJECT_NAME IDS project" 
    debugme echo -e $(cat "$PROJECT_FILE")
    debugme echo -e "curl -k --silent -H "Content-Type: application/json" -X POST -d @$PROJECT_FILE $DRA_URL"
    curl -k --silent -H "Content-Type: application/json" -X POST -d @$PROJECT_FILE $DRA_URL > "$RESPONSE_FILE"
    local RC=$?
    debugme echo -e $(cat "$RESPONSE_FILE")
    rm -f "$PROJECT_FILE"
    if [ $RC == 0 ] && [ $(grep -ci "projectkey" "$RESPONSE_FILE") -ne 0 ]; then
        local PROJECT_KEY_INFO=$(cat "$RESPONSE_FILE")
        export DRA_PROJECT_KEY=$(echo $PROJECT_KEY_INFO | sed 's/.*"projectkey":"//' | awk -F "\"" '{print $1}')
        if [ -n "$DRA_PROJECT_KEY" ]; then
            debugme echo -e "Successfully get the project key ${DRA_PROJECT_KEY}"
        else
            debugme echo -e "Failed to get project key"
            return 1
        fi
        rm -f "$RESPONSE_FILE"
    else
        rm -f "$RESPONSE_FILE"
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
    local RESPONSE_FILE="dra-response.info"
    if [ -e "$RESPONSE_FILE" ]; then
        rm -f "$RESPONSE_FILE"
    fi
    local DRA_ADD_CRITERIAL_URL="http://da.oneibmcloud.com/api/v1/criteria"
    debugme echo -e "Fetching criterial rules to DRA for $CRITERIAL_FILE."
    debugme echo -e "$(cat ${EXT_DIR}/$CRITERIAL_FILE)"
    debugme echo -e "curl -k -H Content-Type:application/json -H projectKey:$DRA_PROJECT_KEY -X POST -d @${EXT_DIR}/$CRITERIAL_FILE $DRA_ADD_CRITERIAL_URL"
    curl -k -H Content-Type:application/json -H projectKey:$DRA_PROJECT_KEY -X POST -d @${EXT_DIR}/$CRITERIAL_FILE $DRA_ADD_CRITERIAL_URL > "$RESPONSE_FILE"
    local RC=$?
    debugme echo -e $(cat "$RESPONSE_FILE")
    echo ""
    if [ $RC == 0 ]; then
        local RESPONSE=$(cat "$RESPONSE_FILE")
        if [ -n "$RESPONSE" ]; then
            if [ $(echo "$RESPONSE" | grep -ci "SyntaxError") -ne 0  ] || [ $(echo "$RESPONSE" | grep -ci "Invalid") -ne 0  ]; then 
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
    local RESULT_FILE=$1
    if [ -n "${RESULT_FILE}" ]; then
        debugme echo -e "Set result rule to DRA in file '${RESULT_FILE}'"
    else
        debugme echo -e "Set result rule to DRA failed. Result rule file is missing."
        return 1
    fi 

    # set the criterial file
#    local RESPONSE_FILE="dra-response.info"
#    if [ -e "$RESPONSE_FILE" ]; then
#        rm -f "$RESPONSE_FILE"
#    fi

    local CMD="-eventType=SecurityScan -file=${RESULT_FILE}"
    debugme echo -e "Fetching result rules to DRA for $RESULT_FILE."
    debugme echo -e "$(cat $RESULT_FILE)"
    debugme echo -e "grunt CMD: grunt --gruntfile=node_modules/grunt-idra/idra.js $CMD"
    local RESPONSE="$(grunt --gruntfile=node_modules/grunt-idra/idra.js $CMD)"
    local RC=$?
    debugme echo -e "$RESPONSE"
    if [ $RC -ne 0 ]; then
        debugme echo -e "Failed to execute grunt command for '${CMD}' with return error code ${RC}"
        return 1
    fi 

    if [ -n "$RESPONSE" ]; then
        if [ $(echo "$RESPONSE" | grep -ci "SyntaxError") -ne 0  ] || [ $(echo "$RESPONSE" | grep -ci "Invalid") -ne 0  ]; then
            return 1
        else
            debugme echo -e "Successfully sent the result rule file $CRITERIAL_FILE to DRA."
       fi
    fi


 #   local DRA_URL="http://da.oneibmcloud.com/api/v1/event"
 #   debugme echo -e "Fetching result rules to DRA for $RESULT_FILE."
 #   debugme echo -e "$(cat $RESULT_FILE)"
 #   debugme echo -e "curl -k -H Content-Type:application/json -H projectKey:$DRA_PROJECT_KEY -X POST -d @$RESULT_FILE $DRA_URL"
 #   curl -k -H Content-Type:application/json -H projectKey:$DRA_PROJECT_KEY -X POST -d @$RESULT_FILE $DRA_URL > "$RESPONSE_FILE"
 #   local RC=$?
 #   debugme echo -e $(cat "$RESPONSE_FILE")
 #   echo ""
 #   if [ $RC == 0 ]; then
 #       local RESPONSE=$(cat "$RESPONSE_FILE")
 #       if [ -n "$RESPONSE" ]; then
 #           echo $RESPONSE | grep "Invalid"
 #           RC=$?
 #           if [ $RC -eq 0 ]; then
 #               return 1
 #           else
 #               debugme echo -e "Successfully sent the result rule file $CRITERIAL_FILE to DRA."
 #          fi
 #       fi
 #   else
 #       debugme echo -e "Failed to send result file $CRITERIAL_FILE to DRA."
 #       return 1
 #   fi
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
    debugme echo -e "$RESPONSE"
    if [ $RC -ne 0 ]; then
        debugme echo -e "Failed to init_dra. init DRA return error code ${RC}"
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
    init_dra
    RC=$?
    if [ $RC -ne 0 ]; then
        debugme echo -e "$WARN" "Failed to init DRA with return error code ${RC}."
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
    dra_grunt_decision "${CRITERIAL_NAME}"
    if [ $RC -ne 0 ]; then
        debugme echo -e "Failed to execute decision for criterial ${CRITERIAL_NAME} with return error code ${RC}."
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

########################################
# run DRA grunt decision command       #
########################################
dra_grunt_decision(){
    local CRITERIAL_NAME=$1
    if [ -n "${CRITERIAL_NAME}" ]; then
        debugme echo -e "dra_grunt_decision for criterial name '${CRITERIAL_NAME}'"
    else
        debugme echo -e "Failed to dra_grunt_decision. criterial name is missing."
        return 1
    fi     

    local CMD="-decision=${CRITERIAL_NAME}"
    debugme echo -e "grunt CMD: grunt --gruntfile=node_modules/grunt-idra/idra.js $CMD"
    local RESPONSE="$(grunt --gruntfile=node_modules/grunt-idra/idra.js $CMD)"
    local RC=$?
    debugme echo -e "$RESPONSE"
    if [ $RC -ne 0 ]; then
        debugme echo -e "Failed to execute grunt command for '${CMD}' with return error code ${RC}"
        return 1
    fi 

    if [ -n "$RESPONSE" ]; then
        echo $RESPONSE | grep "decision"
        RC=$?
        if [ $RC -eq 0 ]; then
            export DRA_DECISION=$(echo $RESPONSE | sed 's/.*"decision":"//' | awk -F "\"" '{print $1}')
            export DRA_REPORT_URL=$(echo $RESPONSE | sed 's/.*Check the report at -//' | awk -F "\"" '{print $1}')
            if [ -n "$DRA_DECISION" ]; then
                if [ "$DRA_DECISION" == "Proceed" ]; then
                    ${EXT_DIR}/utilities/sendMessage.sh -l good -m "Check the Deployment Risk Analytics decision report at - ${DRA_REPORT_URL}"
                    return 0
                elif [ "$DRA_DECISION" == "Stop - Advisory" ]; then
                    ${EXT_DIR}/utilities/sendMessage.sh -l good -m "Check the Deployment Risk Analytics decision report at - ${DRA_REPORT_URL}"
                    return 1
                elif [ "$DRA_DECISION" == "Stop" ]; then
                    ${EXT_DIR}/utilities/sendMessage.sh -l bad -m "Check the Deployment Risk Analytics decision report at - ${DRA_REPORT_URL}"
                    return 2
                else
                    debugme echo -e "Failed to get correct decision result. The DRA_DECISION is ${DRA_DECISION}"
                    return 3
                fi
            else
                debugme echo -e "Failed to get decision result"
                return 4
            fi            
        else
            debugme echo -e "Failed to get decision result"
            return 5                            
        fi
    else
        debugme echo -e "Response is empty"
        return 6        
    fi
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
    local RESULT=$?
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
                    debugme echo -e "$WARN" "DRA is not enabled with return error code ${RESULT}. Could not Add Dynamic Risk Analytics."
                    return 1
                fi
            else
                debugme echo -e "$WARN" "Failed to init DRA with return error code ${RESULT}. Could not Add Dynamic Risk Analytics."
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
export -f dra_grunt_decision
export -f setup_dra
export -f add_result_rule_to_dra
export -f set_event_type

export DRA_PROJECT_KEY
export DRA_ENABLED
export DRA_DECISION
export DRA_REPORT_URL
