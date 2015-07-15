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

# Return codes for success
RC_SEND_MESSAGE_SUCCESS=0

# Return codes for various errors
RC_SLACK_ERROR=1
RC_HIP_CHAT_ERROR=2
RC_SLACK_AND_HIP_CHAT_ERROR=3
RC_NOTIFY_MSG_USAGE=12
RC_NOTIFY_LEVEL_USAGE=13
RC_NO_TOKEN_DEFINED=14
RC_BAD_USAGE=254

# return code variables
slack_ret_value=0
hip_chat_ret_value=0
send_msg_ret_value=0

# Slack color types
SLACK_COLOR_GOOD="good"
SLACK_COLOR_WARNING="warning"
SLACK_COLOR_DANGER="danger"

# HipChat color types
HIP_CHAT_COLOR_GREEN="green"
HIP_CHAT_COLOR_RED="red"
HIP_CHAT_COLOR_GRAY="gray"
HIP_CHAT_COLOR_YELLOW="yellow"
HIP_CHAT_COLOR_PURPLE="purple"
HIP_CHAT_COLOR_RANDOM="random"

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
Usage: [-d] [-l notification_level] -m notification_message
       [-h]

Options:
  -m    (required) Use notification massage for user input.  May container URLs using slack notification format <url|name>.  
        For example: sendMessage.sh -l good -m 'Got 200 response from <http://www.google.com|google> and <http://www.yahoo.com|yahoo>.  Search is alive and well' 
  -l    (recommended) Use notification level for user input. You can set the notification level using the NOTIFICATION_LEVEL environment variable.
        Valid values are 'good', 'info', and 'bad'. 
  -h    Display this help message and exit
  -d    (optional) Debug information  

Notes:
The following environment varaiables should be specify before you call this script
  Slack Notification:
      SLACK_WEBHOOK_PATH: Specify the Slack Webhook URL
        In order to send Slack notification you must specify the Slack Webhook URL
        in an environment variable called 'SLACK_WEBHOOK_PATH' like this:
          SLACK_WEBHOOK_PATH=T00000000/B00000000/XXXXXXXXXXXXXXXXXXXXXXXX
        You can use or create a new Slack Webhook URL using the following steps:
          1. Go to Slack Integration page of your project (https://yourproject.slack.com/services).
          2. Find the Incoming WebHooks and Click on 'Configured'.
          3. You can add new Webhook URL or select existing one.
      SLACK_COLOR: Specify the color of the border along the left side of the message. 
        It is an optional environment variable.
        The value can either be one of 'good', 'warning', 'danger', or any hex color code (eg. #439FE0).
        If you set this optional environment, then, you don't need to set '-l notification_level' option when you call this script.

  HipChat Notification:
      HIP_CHAT_TOKEN: Specify the HipChat token
        In order to send HipChat notification you must specify the HipChat token
        in an environment variable called 'HIP_CHAT_TOKEN':
          HIP_CHAT_TOKEN=XXXXXXXXXXXXXXXXXXXXXXXX
        You can use or create a new HipChat token using the following steps:
          1. Go to your HipChat account page of your project (https://yourproject.hipchat.com/account/api).
          2. Create a new token or use existing one."
      HIP_CHAT_ROOM_NAME: Specify the name of the HipChat room.
      HIP_CHAT_COLOR: Specify the color of the border along the left side of the message and background color.
        It is an optional environment variable.
        The value can either be one of 'yellow', 'red', 'green', 'purple', 'gray', or 'random'.
        If you set this optional environment, then, you don't need to set '-l notification_level' option when you call this script.

  NOTIFICATION_COLOR: Specify the color of the border along the left side of the message and background color.
    It is an optional environment variable and it apply to both Slack and HipChat color.  
    The value can either be one of 'good', 'danger', or 'info'.
    If user specify SLACK_COLOR, HIP_CHAT_COLOR and NOTIFICATION_COLOR, then SLACK_COLOR and HIP_CHAT_COLOR will be used for the notification color.
    If you set this optional environment, then, you don't need to set '-l notification_level' option when you call this script.

  NOTIFICATION_FILTER: Specify the notification message filter level.
    It is an optional environment variable.
    The value can either be one of 'good', 'info', and 'bad'.
    The table below show with 'X" when the notification message will be send based on setting notify level and NOTIFICATION_FILTER.
    |--------------------|--------------------------------------|
    |                    |         NOTIFICATION_FILTER          |
    | notification_level |---------|---------|--------|---------|
    |                    | unknown |   bad   |  good  |  info   |
    |--------------------|---------|---------|--------|---------|
    |    unknown         |    X    |    X    |    X   |   X     |                     
    |--------------------|---------|---------|--------|---------|
    |    bad             |    X    |    X    |    X   |   X     |
    |--------------------|---------|---------|--------|---------|
    |    good            |    X    |         |    X   |   X     |
    |--------------------|---------|---------|--------|---------|
    |    info            |         |         |        |   X     |
    |--------------------|---------|---------|--------|---------|
  
  Set DEBUG=1 for more information or -d 

EOF
}

#############################################################################
# echo messages
#############################################################################
msgid_12()
{
    echo -e "${red}Notification massage must be used when invoking this script.${no_color}"
}

msgid_13()
{
    echo -e "${red}Notification massage must be used with the -l notification_level option when invoking this script.${no_color}."
}

msgid_14()
{
    echo -e "${label_color}To send notifications, please set SLACK_WEBHOOK_PATH or HIP_CHAT_TOKEN in the environment${no_color}"
    if [[ $DEBUG = 1 ]]; then 
        echo -e "In order to send Slack notification you must specify the Slack Webhook URL"
        echo -e "in an environment variable called 'SLACK_WEBHOOK_PATH' like this:"
        echo -e "export SLACK_WEBHOOK_PATH=T00000000/B00000000/XXXXXXXXXXXXXXXXXXXXXXXX"
        echo -e "You can use or create a new Slack Webhook URL using the following steps:"
        echo -e "   1. Go to Slack Integration page of your project (https://yourproject.slack.com/services) "
        echo -e "   2. Find the Incoming WebHooks and Click on 'Configured'"
        echo -e "   3. You can add new Webhook URL or select existing one."
        echo
        echo -e "In order to send HipChat notification you must specify the HipChat token"
        echo -e "in an environment variable called 'HIP_CHAT_TOKEN' like this:"
        echo -e "export $HIP_CHAT_TOKEN=XXXXXXXXXXXXXXXXXXXXXXXX"
        echo -e "You can use or create a new Slack Webhook URL using the following steps:"
        echo -e "   1. Go to your HipChat account page of your project (https://yourproject.hipchat.com/account/api)"
        echo -e "   2. Create a new token or use existing one."
    fi 
}

#############################################################################
# die Function
#############################################################################
die()
{
   msgid_${1}
   exit ${1}
}

#############################################################################
# sendSlackNotify Function
#############################################################################
sendSlackNotify()
{
    local MSG=$1
    local WEBHOOK_PATH=$2
    local COLOR=$3
    local URL=""
    if [ -z "${MSG}" ] || [ -z "${WEBHOOK_PATH}" ]; then
        debugme echo -e "Missing input parameters:  MSG='${MSG}', WEBHOOK_PATH='${WEBHOOK_PATH}"
        return 1
    fi

    debugme echo -e "Slack Webhook URL token: '${WEBHOOK_PATH}'"
    echo $WEBHOOK_PATH | grep "https://hooks.slack.com/services/" >/dev/null
    FULL_PATH=$?
    if [ $FULL_PATH -ne 0 ]; then 
        URL="https://hooks.slack.com/services/$SLACK_WEBHOOK_PATH"
    else 
        URL=$WEBHOOK_PATH
    fi 
    
    if [ -n "${IDS_PROJECT_NAME}" ]; then 
        debugme echo -e "setting sender"
        MY_IDS_PROJECT=${IDS_PROJECT_NAME##*| } 
        MY_IDS_USER=${IDS_PROJECT_NAME%% |*}
        MY_IDS_URL="${IDS_URL}/${MY_IDS_USER}/${MY_IDS_PROJECT}"
        SENDER="<${MY_IDS_URL}|${MY_IDS_PROJECT}-${MY_IDS_USER}>"
        MSG="${SENDER}: ${MSG}"
    else
        debugme echo -e "Sender for this notification message is not defined"
    fi 

    debugme echo -e "Sending slack notification message:  '${MSG}'"

    local PAYLOAD="{\"attachments\":[{""\"text\": \"$MSG\", \"color\": \"$COLOR\"}]}"
    debugme echo -e "Slack Payload: ${PAYLOAD}"

    RESPONSE=$(curl --write-out %{http_code} --silent --output /dev/null -X POST --data-urlencode "payload=$PAYLOAD" $URL)
    RESULT=$?
    if [ "$RESULT" -eq 0 ]; then
        if [ "$RESPONSE" -eq 200 ]; then
            echo -e "${green}Slack notification message has been sent succesfully.${no_color}"
            ret_value=0
        elif [ "$RESPONSE" -eq 404 ]; then
            echo -e "${red}Slack notification message has been failed with (Response code = ${RESPONSE} 'Bad Slack Webhook URL token'.${no_color})"
            ret_value=$RESPONSE
        elif [ "$RESPONSE" -eq 500 ]; then
            echo -e "${red}Slack notification message has been failed with (Response code = ${RESPONSE} 'Salck Payload was not valid'.${no_color})"
            ret_value=$RESPONSE
        else
            echo -e "${red}Slack notification message has been failed with (Response code = ${RESPONSE}).${no_color}"
            ret_value=$RESPONSE
        fi
    else
        echo -e "${red}curl command failed with retun code value ${RESULT}${no_color}"
        ret_value=$RESULT

    fi

    debugme echo -e "slack_ret_value: ${slack_ret_value}"
    export slack_ret_value=$ret_value
}

#############################################################################
# sendHipChatNotify Functions
#############################################################################
sendHipChatNotify()
{
    local MSG=$1
    local ROOM_NAME=$2
    local AUTH_TOKEN=$3
    local COLOR=$4
    if [ -z "${MSG}" ] || [ -z "${ROOM_NAME}" ] || [ -z "${AUTH_TOKEN}" ]; then
        debugme echo -e "Missing input parameters:  MSG='${MSG}', ROOM_NAME='${ROOM_NAME}, AUTH_TOKEN='${AUTH_TOKEN}"
        return 1
    fi
    debugme echo -e "Verify HipChat room name: '${ROOM_NAME}' and token: '${AUTH_TOKEN}'"

    # Validate the COLOR
    if [ -z "$COLOR" ]; then
        debugme echo -e "HipChat color is not defined. setting to 'gray' color"
        COLOR="${HIP_CHAT_COLOR_GRAY}"
    elif [ "${COLOR}" == "${HIP_CHAT_COLOR_GREEN}" ] || \
         [ "${COLOR}" == "${HIP_CHAT_COLOR_RED}" ] || \
         [ "${COLOR}" == "${HIP_CHAT_COLOR_GRAY}" ] || \
         [ "${COLOR}" == "${HIP_CHAT_COLOR_YELLOW}" ] || \
         [ "${COLOR}" == "${HIP_CHAT_COLOR_PURPLE}" ] || \
         [ "${COLOR}" == "${HIP_CHAT_COLOR_RANDOM}" ]; then
        debugme echo -e "Valid HipChat color: ${COLOR}"
    else
        debugme echo -e "Invalid HipChat color ${COLOR}. setting to 'gray' color"
        COLOR="${HIP_CHAT_COLOR_GRAY}"
    fi

    # If we are running in an IDS job set a URL for the sender 
    if [ -n "${IDS_PROJECT_NAME}" ]; then 
        debugme echo -e "setting sender"
        MY_IDS_PROJECT=${IDS_PROJECT_NAME##*| } 
        MY_IDS_USER=${IDS_PROJECT_NAME%% |*}
        MY_IDS_URL="${IDS_URL}/${MY_IDS_USER}/${MY_IDS_PROJECT}"
        MSG="${MY_IDS_URL}: ${MSG}"
    else
        debugme echo -e "Sender for this notification message is not defined"
    fi 
    
    # replace the spaces with %20
    ROOM_NAME=`echo "$ROOM_NAME"|sed 's/ /%20/g'`
    local ret_value=0
    local RESPONSE=$(curl --write-out %{http_code} --silent --output /dev/null http://api.hipchat.com/v2/room?auth_token=$AUTH_TOKEN)
    local RESULT=$?
    if [ "$RESULT" -eq 0 ]; then
        if [ "$RESPONSE" -eq 200 ]; then
            debugme echo -e "${green}Valid HipChat token.${no_color}"
        else
            echo -e "${red}Validation of HipChat token has been failed with (Response code = ${RESPONSE}).${no_color}"
            ret_value=$RESPONSE
        fi
         # replace message 
        MSG_FILTER="init"
        while [ -n "$MSG_FILTER" ]; do 
            MSG_FILTER=$(echo $MSG | sed -n -e 's/^\(.*\)<\(.*\)|\(.*\)>\(.*\)$/\1\2\4/p')
            if [ -n "$MSG_FILTER" ]; then 
                debugme echo "replaced message $MSG with $MSG_FILTER"
                MSG=$MSG_FILTER
            else 
                debugme echo "did not replace $MSG"
            fi 
        done 

        debugme echo -e "Sending notification message:  '${MSG}'"
        local HIP_CHAT_URL="https://api.hipchat.com/v2/room/${ROOM_NAME}/notification"
        debugme echo -e "HIP_CHAT_URL: ${HIP_CHAT_URL}"
        local PAYLOAD="{\"color\": \"$COLOR\", \"message_format\": \"text\", \"message\": \"$MSG\"}"
        debugme echo -e "HipChat Payload: ${PAYLOAD}"
        RESPONSE=$(curl --write-out %{http_code} --silent --output /dev/null \
                        -H "Content-type: application/json" \
                        -H "Authorization: Bearer $AUTH_TOKEN" \
                        -X POST \
                        -d "$PAYLOAD" $HIP_CHAT_URL)
        RESULT=$?
        if [ "$RESULT" -eq 0 ]; then
            if [ "$RESPONSE" -eq 200 ] || [ "$RESPONSE" -eq 204 ]; then
                echo -e "${green}HipChat notification message has been sent succesfully.${no_color}"
                ret_value=0
            elif [ "$RESPONSE" -eq 401 ]; then
                echo -e "${red}HipChat notification message has been failed with (Response code = ${RESPONSE} 'Bad HipChat token'.${no_color})"
                ret_value=$RESPONSE
            elif [ "$RESPONSE" -eq 400 ]; then
                echo -e "${red}HipChat notification message has been failed with (Response code = ${RESPONSE} 'HipChat Payload was not valid'.${no_color})"
                ret_value=$RESPONSE
            elif [ "$RESPONSE" -eq 404 ]; then
                echo -e "${red}HipChat notification message has been failed with (Response code = ${RESPONSE} 'HipChat room not found'.${no_color})"
                ret_value=$RESPONSE
            else
                echo -e "${red}HipChat notification message has been failed with (Response code = ${RESPONSE}).${no_color}"
                ret_value=$RESPONSE
            fi
        else
            echo -e "${red}curl command to send HipChat notification failed with retun code value ${RESULT}${no_color}"
            ret_value=$RESULT
        fi
    else
        echo -e "${red}curl command to verify the HipChat token failed with retun code value ${RESULT}${no_color}"
        ret_value=$RESULT
    fi

    debugme echo -e "hip_chat_ret_value: ${hip_chat_ret_value}"
    export hip_chat_ret_value=$ret_value
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
 
if [ -n "$MESSAGE_COLOR" ]; then
    NOTIFICATION_COLOR=$MESSAGE_COLOR
fi
if [ -n "NOTIFY_FILTER" ]; then
    NOTIFICATION_FILTER=$NOTIFY_FILTER
fi
if [ -n "NOTIFICATION_LEVEL" ]; then
    NOTIFY_LEVEL=$NOTIFICATION_LEVEL
fi
 
debugme echo -e "Script Input:  NOTIFY_LEVEL = '${NOTIFY_LEVEL}', NOTIFY_MSG = '${NOTIFY_MSG}'"
debugme echo -e "Slack environment variables:  SLACK_COLOR = '${SLACK_COLOR}' SLACK_WEBHOOK_PATH = '${SLACK_WEBHOOK_PATH}'"
debugme echo -e "HipChat environment variables:  HIP_CHAT_COLOR = '${HIP_CHAT_COLOR}', HIP_CHAT_ROOM_NAME = '${HIP_CHAT_ROOM_NAME}, HIP_CHAT_TOKEN = '${HIP_CHAT_TOKEN}'"
debugme echo -e "Common environment variables: NOTIFICATION_COLOR = '${NOTIFICATION_COLOR}', NOTIFICATION_FILTER = '${NOTIFICATION_FILTER}'"
 
# Check NOTIFICATION_FILTER and NOTIFY_LEVEL to set sendMsg boolean  
sendMsg=true
if [ -z "$NOTIFICATION_FILTER" ]; then 
    if [ -n "$NOTIFY_LEVEL" ] && [ "$NOTIFY_LEVEL" == "info" ]; then
        sendMsg=false
    fi
else 
    NOTIFICATION_FILTER=$(echo $NOTIFICATION_FILTER | tr '[:upper:]' '[:lower:]')
    if [ "$NOTIFICATION_FILTER" == "bad" ]; then
        if [ -n "$NOTIFY_LEVEL" ] && [ "$NOTIFY_LEVEL" == "good" ] || [ "$NOTIFY_LEVEL" == "info" ]; then
            sendMsg=false
        fi
    elif [ "$NOTIFICATION_FILTER" == "good" ]; then
        if [ -n "$NOTIFY_LEVEL" ] && [ "$NOTIFY_LEVEL" == "info" ]; then
            sendMsg=false
        fi
    elif [ "$NOTIFICATION_FILTER" != "info" ]; then
        if [ -n "$NOTIFY_LEVEL" ] && [ "$NOTIFY_LEVEL" == "info" ]; then
            sendMsg=false
        fi
    fi
fi

if [ "$sendMsg" == false ]; then
    if [ -n "$SLACK_WEBHOOK_PATH" ] || [ -n "$HIP_CHAT_TOKEN" ]; then
        echo -e "skipped sending Notification message because the NOTIFICATION_FILTER = '${NOTIFICATION_FILTER}' and NOTIFICATION_LEVEL = '${NOTIFY_LEVEL}'"
    fi
else
    if [ -z "$SLACK_WEBHOOK_PATH" ] && [ -z "$HIP_CHAT_TOKEN" ]; then
        die ${RC_NO_TOKEN_DEFINED}
    else
        # Slack Notification
        if [ -n "$SLACK_WEBHOOK_PATH" ]; then
        
            # Check if the SLACK_COLOR set in environment variable, then use SLACK_COLOR for the setting the color.
            # If SLACK_COLOR is not set, then check if the NOTIFICATION_COLOR set and use NOTIFICATION_COLOR for the setting the color.
            # If SLACK_COLOR and NOTIFICATION_COLOR are not set, then check the NOTIFY_LEVEL and set the SLACK_COLOR based on NOTIFY_LEVEL setting.
            # If SLACK_COLOR, NOTIFICATION_COLOR and NOTIFY_LEVEL are not set, then don't specify the color and set SLACK_COLOR to null.
            if [ -z "$SLACK_COLOR" ] && [ -z "$NOTIFICATION_COLOR" ]; then
                 if [ -n "$NOTIFY_MSG" ] && [ -n "$NOTIFY_LEVEL" ]; then
                    NOTIFY_LEVEL=$(echo $NOTIFY_LEVEL | tr '[:upper:]' '[:lower:]')
                    case $NOTIFY_LEVEL in
                        GOOD|good)
                            SLACK_COLOR=$SLACK_COLOR_GOOD;;
                        BAD|bad)
                            SLACK_COLOR=$SLACK_COLOR_DANGER;;
                        INFO|info)
                            SLACK_COLOR="#c3cab9";;
                        *) 
                            SLACK_COLOR="";;
                    esac
                else
                    SLACK_COLOR=""
                fi
            elif [ -z "$SLACK_COLOR" ] && [ -n "$NOTIFICATION_COLOR" ]; then
                SLACK_COLOR=$(echo $NOTIFICATION_COLOR | tr '[:upper:]' '[:lower:]')
                case $SLACK_COLOR in
                    GOOD|good)
                        SLACK_COLOR=$SLACK_COLOR_GOOD;;
                    DANGER|danger)
                        SLACK_COLOR=$SLACK_COLOR_DANGER;;
                    INFO|info)
                        SLACK_COLOR="#c3cab9";;
                    *) 
                        SLACK_COLOR="";;
                esac
            else
                SLACK_COLOR=$(echo $SLACK_COLOR | tr '[:upper:]' '[:lower:]')
            fi

            # Send message to the Slack
            sendSlackNotify "${NOTIFY_MSG}" "${SLACK_WEBHOOK_PATH}" "${SLACK_COLOR}"
        fi

        # HipChat Notification
        if [ -n "$HIP_CHAT_TOKEN" ]; then

            # Check if the HIP_CHAT_COLOR set in environment variable, then use HIP_CHAT_COLOR for the setting the color.
            # If HIP_CHAT_COLOR is not set, then check if the NOTIFICATION_COLOR set and use NOTIFICATION_COLOR for the setting the color.
            # If HIP_CHAT_COLOR and NOTIFICATION_COLOR are not set, then check the NOTIFY_LEVEL and set the HIP_CHAT_COLOR based on NOTIFY_LEVEL setting.
            # If HIP_CHAT_COLOR, NOTIFICATION_COLOR and NOTIFY_LEVEL are not set, then don't specify the color and set HIP_CHAT_COLOR to null.
            if [ -z "$HIP_CHAT_COLOR" ] && [ -z "$NOTIFICATION_COLOR" ]; then
                 if [ -n "$NOTIFY_MSG" ] && [ -n "$NOTIFY_LEVEL" ]; then
                    NOTIFY_LEVEL=$(echo $NOTIFY_LEVEL | tr '[:upper:]' '[:lower:]')
                    case $NOTIFY_LEVEL in
                        GOOD|good)
                            HIP_CHAT_COLOR=$HIP_CHAT_COLOR_GREEN;;
                        BAD|bad)
                            HIP_CHAT_COLOR=$HIP_CHAT_COLOR_RED;;
                        INFO|info)
                            HIP_CHAT_COLOR=$HIP_CHAT_COLOR_GRAY;;
                        *) 
                            HIP_CHAT_COLOR=$HIP_CHAT_COLOR_GRAY;;
                    esac
                fi
            elif [ -z "$HIP_CHAT_COLOR" ] && [ -n "$NOTIFICATION_COLOR" ]; then
                HIP_CHAT_COLOR=$(echo $NOTIFICATION_COLOR | tr '[:upper:]' '[:lower:]')
                case $HIP_CHAT_COLOR in
                    GOOD|good)
                        HIP_CHAT_COLOR=$HIP_CHAT_COLOR_GREEN;;
                    DANGER|danger)
                        HIP_CHAT_COLOR=$HIP_CHAT_COLOR_RED;;
                    INFO|info)
                        HIP_CHAT_COLOR=$HIP_CHAT_COLOR_GRAY;;
                    *) 
                        HIP_CHAT_COLOR=$HIP_CHAT_COLOR_GRAY;;
                esac
            else
                HIP_CHAT_COLOR=$(echo $HIP_CHAT_COLOR | tr '[:upper:]' '[:lower:]')
            fi

            if [ -z ${HIP_CHAT_ROOM_NAME} ]; then 
                echo "HIP_CHAT_ROOM_NAME must be set when using HIP_CHAT_TOKEN" 
                exit $RC_HIP_CHAT_ERROR
            fi 

            # Send message to the HipChat
            sendHipChatNotify "${NOTIFY_MSG}" "${HIP_CHAT_ROOM_NAME}" "${HIP_CHAT_TOKEN}" "${HIP_CHAT_COLOR}"
        fi
    fi

    # Check for the return code
    if [ $slack_ret_value -eq 0 ] && [ $hip_chat_ret_value -eq 0 ]; then
        exit $RC_SEND_MESSAGE_SUCCESS
    elif [ $slack_ret_value -ne 0 ] && [ $hip_chat_ret_value -eq 0 ]; then
        exit $RC_SLACK_ERROR
    elif [ $slack_ret_value -eq 0 ] && [ $hip_chat_ret_value -ne 0 ]; then
        exit $RC_HIP_CHAT_ERROR
    elif [ $slack_ret_value -ne 0 ] && [ $hip_chat_ret_value -ne 0 ]; then
        exit $RC_SLACK_AND_HIP_CHAT_ERROR
    fi
fi
