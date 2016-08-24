Feature: Test all flags for group create against gp_create.py
Make sure that gp_create.py works with all flags needed for group create


Scenario: Default
Given Command ../gp_create.py
And Parameter --name ${GROUP_NAME}1
And Parameter $IMGNAME
When The command is run
Then The group ${GROUP_NAME}1 is created
And Value AntiAffinity is false
And Value Autorecovery is false
And Value Memory is 256
And Child CurrentSize of NumberInstances is 2
And Child Desired of NumberInstances is 2
And Child Max of NumberInstances is 2
And Child Min of NumberInstances is 1
And Value Port is None
And List Routes is empty
And List Cmd is empty

Scenario: --anti and -m 64
Given Command ../gp_create.py
And Parameter --name ${GROUP_NAME}2
And Parameter --anti
And Parameter -m 64
And Parameter $IMGNAME
When The command is run
Then The group ${GROUP_NAME}2 is created
And Value AntiAffinity is true
And Value Autorecovery is false
And Value Memory is 64
And Child CurrentSize of NumberInstances is 2
And Child Desired of NumberInstances is 2
And Child Max of NumberInstances is 2
And Child Min of NumberInstances is 1
And Value Port is None
And List Routes is empty
And List Cmd is empty

Scenario: --anti, --auto, -m 64, -P, Min, Max, Desired
Given Command ../gp_create.py
And Parameter --name ${GROUP_NAME}3
And Parameter --anti
And Parameter -m 64
And Parameter --auto
And Parameter --min 2 --max 4 --desired 3
And Parameter -P
And Parameter $IMGNAME
When The command is run
Then The group ${GROUP_NAME}3 is created
And Value AntiAffinity is true
And Value Autorecovery is true
And Value Memory is 64
And Child CurrentSize of NumberInstances is 3
And Child Desired of NumberInstances is 3
And Child Max of NumberInstances is 4
And Child Min of NumberInstances is 2
And Value Port is $PORT
And List Routes is empty
And List Cmd is empty

@routes
Scenario: -p 8080, --anti, --auto, --memory=64, -n $HOSTNAME -d $DOMAIN -p $PORT
Given Command ../gp_create.py
And Parameter --name ${GROUP_NAME}4
And Parameter -p $PORT
And Parameter --anti
And Parameter --memory=64
And Parameter --auto
And Parameter -n $HOSTNAME -d $DOMAIN
And Parameter $IMGNAME
When The command is run
Then The group ${GROUP_NAME}4 is created
And Value AntiAffinity is true
And Value Autorecovery is true
And Value Memory is 64
And Child CurrentSize of NumberInstances is 2
And Child Desired of NumberInstances is 2
And Child Max of NumberInstances is 2
And Child Min of NumberInstances is 1
And Value Port is $PORT
And List Routes contains ${HOSTNAME}.${DOMAIN}
And List Cmd is empty

@cmd
Scenario: pass in a command
Given Command ../gp_create.py
And Parameter --name ${GROUP_NAME}5
And Parameter --memory=64
And Parameter $IMGNAME
And Parameter ping localhost
When The command is run
Then The group ${GROUP_NAME}5 is created
And Value AntiAffinity is false
And Value Autorecovery is false
And Value Memory is 64
And Child CurrentSize of NumberInstances is 2
And Child Desired of NumberInstances is 2
And Child Max of NumberInstances is 2
And Child Min of NumberInstances is 1
And Value Port is None
And List Routes is empty
And List Cmd contains ping
And List Cmd contains localhost