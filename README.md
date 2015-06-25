# utilities
Set of utility scripts used by IBM DevOps Services extensions

# logging_utils.sh 
Purpose: Provide a common utility to log a message to the console, and send to Logging Service from a bash script

# sendMessage.sh 
Purpose:  Send a notification message.

Description:

A simple bash script to send a notification message. It is currently supported for Slack and HipChat. 
It requires Slack Webhook URL token to be specified for stack notification. 
It requires HipChat room name and HipChat token to be specified for HipChat notification. 

Synopsis:

    ./sendMessage.sh [-h ]
    ./sendMessage.sh [-d] [-l notify_level] -m notify_message

Usage:  

        [-d] [-l notify_level] -m notify_message
        [-h]

Options:

        -h      Display this help message and exit
        -m      (required) Use notification massage for user input
                For example: sendMessage.sh -l good -m 'Got 200 response from <http://www.google.com|google> and <http://www.yahoo.com|yahoo>.  Search is alive and well' 
        -l      (recommended) Use notification level for user input. You can set the notification level using the NOTIFY_LEVEL environment variable.
                Valid values are 'good', 'info', and 'bad'. 
        -d      (optional) Debug information 

Notes:

The following environment varaiables should be specify before you call this script

        Slack Notification:

                SLACK_WEBHOOK_PATH: Specify the Slack Webhook URL
                        In order to send Slack notification you must specify the Slack Webhook URL
                        in an environment variable called 'SLACK_WEBHOOK_PATH':

                                SLACK_WEBHOOK_PATH=T00000000/B00000000/XXXXXXXXXXXXXXXXXXXXXXXX

                        You can use or create a new Slack Webhook URL using the following steps:
                                1. Go to Slack Integration page of your project (https://yourproject.slack.com/services).
                                2. Find the Incoming WebHooks and Click on 'Configured'.
                                3. You can add new Webhook URL or select existing one.

                SLACK_COLOR: Specify the color of the border along the left side of the message. 
                        It is an optional environment variable.
                        The value can either be one of 'good', 'warning', 'danger', or any hex color code (eg. #439FE0).
                        If you set this optional environment, then, you don't need to set '-l notify_level' option when you call this script.

        HipChat Notification:

                HIP_CHAT_TOKEN: Specify the HipChat token
                        In order to send HipChat notification you must specify the HipChat token
                        in an environment variable called 'HIP_CHAT_TOKEN' like this:

                                HIP_CHAT_TOKEN=XXXXXXXXXXXXXXXXXXXXXXXX

                        You can use or create a new HipChat token using the following steps:
                                1. Go to your HipChat account page of your project (https://yourproject.hipchat.com/account/api).
                                2. Create a new token or use existing one."

                HIP_CHAT_ROOM_NAME: Specify the name of the HipChat room.

                HIP_CHAT_COLOR: Specify the color of the border along the left side of the message and background color.
                        It is an optional environment variable.
                        The value can either be one of 'yellow', 'red', 'green', 'purple', 'gray', or 'random'.
                        If you set this optional environment, then, you don't need to set '-l notify_level' option when you call this script.

        MESSAGE_COLOR: Specify the color of the border along the left side of the message and background color.
                It is an optional environment variable and it apply to both Slack and HipChat color.  
                The value can either be one of 'good', 'danger', or 'info'.
                If user specify SLACK_COLOR, HIP_CHAT_COLOR and MESSAGE_COLOR, then SLACK_COLOR and HIP_CHAT_COLOR will be used for the notification color.
                If you set this optional environment, then, you don't need to set '-l notify_level' option when you call this script.

        NOTIFY_FILTER: Specify the message filter level.
                It is an optional environment variable.
                The value can either be one of 'good', 'info', and 'bad'.
                The table below show with 'X" when the notification message will be send based on setting notification level and NOTIFY_FILTER.

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

