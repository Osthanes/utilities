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

#############
# Colors    #
#############
export green='\e[0;32m'
export red='\e[0;31m'
export label_color='\e[0;33m'
export no_color='\e[0m' # No Color

# Return codes for various errors
RC_BAD_USAGE=254
RC_NOTIFY_MSG_USAGE=2
RC_NOTIFY_LEVEL_USAGE=3
RC_SLACK_WEBHOOK_PATH=4

# Slack color types
SLACK_COLOR_GOOD="good"
SLACK_COLOR_WARNING="warning"
SLACK_COLOR_DANGER="danger"

debugme() {
  [[ $DEBUG = 1 ]] && "$@" || :
}

#############################################################################
# usage
#############################################################################

usage()
{
   /bin/cat << EOF
Send notification massage.
Usage: [-d] [-l notify_level] -m notify_message
       [-h]

Options:
  -m    (required) Use notification massage for user input
  -l    (recommended) Use notification level for user input. You can set the notification level using the NOTIFY_LEVEL environment variable.
        Valid values are 'good', 'info', and 'bad'. 
  -h    Display this help message and exit
  -d    (optional) Debug information  

Notes:
  SLACK_WEBHOOK_PATH: Specify the Slack Webhook URL
    In order to send Slack notification you must specify the Slack Webhook URL
    in an environment variable called 'SLACK_WEBHOOK_PATH' like this:
      SLACK_WEBHOOK_PATH=T00000000/B00000000/XXXXXXXXXXXXXXXXXXXXXXXX
    You can use or create a new Slack Webhook URL using the following steps:
      1. Go to Slack Integration page of your project (https://blue-alchemy.slack.com/services).
      2. Find the Incoming WebHooks and Click on 'Configured'.
      3. You can add new Webhook URL or select existing one.
  SLACK_COLOR: Specify the color of the border along the left side of the message. 
    It is an optional environment variable.
    The value can either be one of 'good', 'warning', 'danger', or any hex color code (eg. #439FE0).
    If you set this optional environment, then, you don't need to set '-l notify_level' option when you call this script.
  NOTIFY_FILTER: Specify the message filter level.
    It is an optional environment variable.
    The value can either be one of 'good', 'info', and 'bad'.
    The table below show with 'X" wjen the notification message will be send based on setting notification level and NOTIFY_FILTER.
    |---------------|--------------------------------------|
    |               |             NOTIFY_FILTER            |
    |---------------|---------|---------|--------|---------|
    |  notify_level | unknown |   bad   |  good  |  info   |
    |---------------|---------|---------|--------|---------|
    |    unknown    |    X    |    X    |    X   |   X     |                     
    |---------------|---------|---------|--------|---------|
    |    bad        |    X    |    X    |    X   |   X     |
    |---------------|---------|---------|--------|---------|
    |    good       |    X    |         |    X   |   X     |
    |---------------|---------|---------|--------|---------|
    |    info       |         |         |        |   X     |
    |---------------|---------|---------|--------|---------|
  
  Set DEBUG=1 for more information or -d 

EOF
}

#############################################################################
# echo messages
#############################################################################
msgid_2()
{
    echo -e "${red}Notification massage must be used when invoking this script.${no_color}"
}

msgid_3()
{
    echo -e "${red}Notification massage must be used with the -l notify_level option when invoking this script.${no_color}."
}

msgid_4()
{
    echo -e "${label_color}To send slack notifications set SLACK_WEBHOOK_PATH in the environment${no_color}"
    if [[ $DEBUG = 1 ]]; then 
        echo -e "In order to send Slack notification you must specify the Slack Webhook URL"
        echo -e "in an environment variable called 'SLACK_WEBHOOK_PATH' like this:"
        echo -e "export SLACK_WEBHOOK_PATH=T00000000/B00000000/XXXXXXXXXXXXXXXXXXXXXXXX"
        echo -e "You can use or create a new Slack Webhook URL using the following steps:"
        echo -e "   1. Go to Slack Integration page of your project (https://blue-alchemy.slack.com/services) "
        echo -e "   2. Find the Incoming WebHooks and Click on 'Configured'"
        echo -e "   3. You can add new Webhook URL or select existing one."
    fi 
}

#############################################################################
# die Functions
#############################################################################
die()
{
   msgid_${1}
   exit ${1}
}

#############################################################################
# Main
#############################################################################

# Set options from the command line.
while getopts ":m:l:h:d" FLAG; do
   case ${FLAG} in
      m) NOTIFY_MSG=${OPTARG} ;;
      l) NOTIFY_LEVEL=${OPTARG} ;;
      h) usage && exit 0;;
      d) export DEBUG=1;;
      ?) usage && exit ${RC_BAD_USAGE}
   esac
done

shift $((OPTIND-1))
INVALID_ARGUMENTS=$*
[ -n "${INVALID_ARGUMENTS}" ] && usage && exit ${RC_BAD_USAGE}
[ -z "${NOTIFY_MSG}" ] && usage && die ${RC_NOTIFY_MSG_USAGE}
[ -z "${NOTIFY_LEVEL}" ] && [ -z "${NOTIFY_MSG}" ] && usage && die ${RC_NOTIFY_LEVEL_USAGE}

# Check if the SLACK_COLOR set in environment variable, then use SLACK_COLOR for the setting the color.
# If SLACK_COLOR is not set, then check the NOTIFY_LEVEL and set it to the SLACK_COLOR.
# If both SLACK_COLOR and NOTIFY_LEVEL are not set, then don't specify the color by setting SLACK_COLOR to null. 
if [ -z "$SLACK_COLOR" ]; then 
    if [ -n "$NOTIFY_MSG" ] && [ -n "$NOTIFY_LEVEL" ]; then
        NOTIFY_LEVEL=$(echo $NOTIFY_LEVEL | tr '[:upper:]' '[:lower:]')
        case $NOTIFY_LEVEL in
            GOOD|good)
                SLACK_COLOR=$SLACK_COLOR_GOOD;;
            BAD|bad)
                SLACK_COLOR=$SLACK_COLOR_DANGER;;
            INFO|info)
                SLACK_COLOR=$SLACK_COLOR_WARNING;;
            *) 
                SLACK_COLOR="";;
        esac
    fi
else
    SLACK_COLOR=$(echo $SLACK_COLOR | tr '[:upper:]' '[:lower:]')
fi
 
debugme echo -e "Input Info:  SLACK_COLOR = '${SLACK_COLOR}', NOTIFY_FILTER = '${NOTIFY_FILTER}', NOTIFY_LEVEL = '${NOTIFY_LEVEL}', NOTIFY_MSG = '${NOTIFY_MSG}'"
 
sendMsg=true
if [ -z "$NOTIFY_FILTER" ]; then 
    if [ -n "$NOTIFY_LEVEL" ] && [ "$NOTIFY_LEVEL" != "bad" ] && [ "$NOTIFY_LEVEL" != "good" ]; then
        sendMsg=false
    fi
else 
    NOTIFY_FILTER=$(echo $NOTIFY_FILTER | tr '[:upper:]' '[:lower:]')
    if [ "$NOTIFY_FILTER" == "bad" ]; then
        if [ -n "$NOTIFY_LEVEL" ] && [ "$NOTIFY_LEVEL" != "bad" ]; then
            sendMsg=false
        fi
    elif [ "$NOTIFY_FILTER" == "good" ]; then
        if [ -n "$NOTIFY_LEVEL" ] && [ "$NOTIFY_LEVEL" != "bad" ] && [ "$NOTIFY_LEVEL" != "good" ]; then
            sendMsg=false
        fi
    elif [ "$NOTIFY_FILTER" == "info" ]; then
        if [ -n "$NOTIFY_LEVEL" ] && [ "$NOTIFY_LEVEL" != "bad" ] && [ "$NOTIFY_LEVEL" != "good" ] && [ "$NOTIFY_LEVEL" != "info" ]; then
            sendMsg=false
        fi    
    else
        if [ -n "$NOTIFY_LEVEL" ] && [ "$NOTIFY_LEVEL" != "bad" ] && [ "$NOTIFY_LEVEL" != "good" ]; then
            sendMsg=false
        fi
    fi
fi

if [ "$sendMsg" == false ]; then
    echo -e "Ignoring to send Notification message because the NOTIFY_FILTER = '${NOTIFY_FILTER}' and NOTIFY_LEVEL = '${NOTIFY_LEVEL}'"
else
    # Check if the message token has been set
    if [ -z "$SLACK_WEBHOOK_PATH" ]; then
        die ${RC_SLACK_WEBHOOK_PATH}
    else
        debugme echo -e "Slack Webhook URL token: '${SLACK_WEBHOOK_PATH}'"
    fi

    # Send message to the Slack
    if [ -n "$SLACK_WEBHOOK_PATH" ]; then
        echo $SLACK_WEBHOOK_PATH | grep "https://hooks.slack.com/services/" >/dev/null
        FULL_PATH=$?
        if [ $FULL_PATH -ne 0 ]; then 
            URL="https://hooks.slack.com/services/$SLACK_WEBHOOK_PATH"
        else 
            URL=$SLACK_WEBHOOK_PATH
        fi 

        MSG="${NOTIFY_MSG}"

        # If we are running in an IDS job set a URL for the sender 
        if [ -n "${IDS_PROJECT_NAME}" ]; then 
            debugme echo -e "setting sender"
            MY_IDS_PROJECT=${IDS_PROJECT_NAME##*| } 
            MY_IDS_USER=${IDS_PROJECT_NAME%% |*}
            MY_IDS_URL="${IDS_URL}/${MY_IDS_USER}/${MY_IDS_PROJECT}"
            SENDER="<${MY_IDS_URL}|${MY_IDS_PROJECT}-${MY_IDS_USER}>"
            MSG="${SENDER}: ${NOTIFY_MSG}"
        else
            debugme echo -e "Sender of notification message is not defined"
        fi 

        echo -e "Sending notification message:  '${NOTIFY_MSG}'"

        PAYLOAD="{\"attachments\":[{""\"text\": \"$MSG\", \"color\": \"$SLACK_COLOR\"}]}"
        debugme echo -e "Slack Payload: ${PAYLOAD}"

        RESPONSE=$(curl --write-out %{http_code} --silent --output /dev/null -X POST --data-urlencode "payload=$PAYLOAD" $URL)
        RESULT=$?
        if [ "$RESULT" -eq 0 ]; then
            if [ "$RESPONSE" -eq 200 ]; then
                echo -e "${green}Slack notification message has been sent succesfully.${no_color}"
                exit 0
            elif [ "$RESPONSE" -eq 404 ]; then
                echo -e "${red}Slack notification message has been failed with (Response code = ${RESPONSE} 'Bad Slack Webhook URL token'.${no_color})"
                exit $RESPONSE
            elif [ "$RESPONSE" -eq 500 ]; then
                echo -e "${red}Slack notification message has been failed with (Response code = ${RESPONSE} 'Salck Payload was not valid'.${no_color})"
                exit $RESPONSE
            else
                echo -e "${red}Slack notification message has been failed with (Response code = ${RESPONSE}).${no_color}"
                exit $RESPONSE
            fi
        else
            echo -e "${red}curl command failed with retun code value ${RESULT}${no_color}"
            exit $RESULT

        fi
   fi
fi
