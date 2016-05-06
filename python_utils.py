#!/usr/bin/python

#***************************************************************************
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
#***************************************************************************

# To import this package in an extension run the following in _init.sh:
#    export PYTHONPATH=$EXT_DIR/utilities:$PYTHONPATH


import json
import logging
import logging.handlers
import os
import os.path
import sys
import timeit
from subprocess import call, Popen, PIPE

# ascii color codes for output
LABEL_GREEN='\033[0;32m'
LABEL_RED='\033[0;31m'
LABEL_COLOR='\033[0;33m'
LABEL_NO_COLOR='\033[0m'
STARS="**********************************************************************"


DEFAULT_SERVICE_PLAN="free"
DEFAULT_SERVICE_KEY="pipeline_service_key"
DEFAULT_BRIDGEAPP_NAME="pipeline_bridge_app"
EXT_DIR=os.getenv('EXT_DIR', ".")
DEBUG=os.environ.get('DEBUG')


SCRIPT_START_TIME = timeit.default_timer()
LOGGER = None


FULL_WAIT_TIME = 5
WAIT_TIME = 0


# setup logmet logging connection if it's available
def setup_logging ():
    logger = logging.getLogger('pipeline')
    if DEBUG:
        logger.setLevel(logging.DEBUG)
    else:
        logger.setLevel(logging.INFO)

    # if logmet is enabled, send the log through our pipeline logfile as well
    if os.environ.get('LOGMET_LOGGING_ENABLED'):
        pipeline_logfile = os.environ.get('PIPELINE_LOGGING_FILE')
        if pipeline_logfile:
            handler = logging.FileHandler(pipeline_logfile)
            logger.addHandler(handler)
            # don't send debug info through syslog
            handler.setLevel(logging.INFO)
            # set formatting on this to be json style
            formatter = logging.Formatter('{\"@timestamp\": \"%(asctime)s\", \"loglevel\": \"%(levelname)s\", \"module\": \"%(name)s\", \"message\": \"%(message)s\"}\n')
            handler.setFormatter(formatter)

    # in any case, dump logging to the screen
    handler = logging.StreamHandler(sys.stdout)
    formatter = logging.Formatter('%(asctime)s - %(name)s - %(levelname)s - %(message)s')
    handler.setFormatter(formatter)
    if DEBUG:
        handler.setLevel(logging.DEBUG)
    else:
        handler.setLevel(logging.INFO)
    logger.addHandler(handler)
    
    return logger


# load bearer token and space guid from ~/.cf/config.json
# used for a variety of things, including calls to the CCS server
def load_cf_auth_info ():

    bearer_token = None
    space_guid = None

    cf_filename = "%s/.cf/config.json" % os.path.expanduser("~")

    with open( cf_filename ) as cf_config_file:
        config_info = json.load(cf_config_file)
        bearer_token = config_info["AccessToken"]
        if bearer_token.lower().startswith("bearer "):
            bearer_token=bearer_token[7:]
        space_guid = config_info["SpaceFields"]["Guid"]

    return bearer_token, space_guid


# check with cf to find the api server
# adjust to find the ICE api server
# return both
def find_api_servers ():

    cf_api_server = None
    ice_api_server = None

    command = "cf api"
    proc = Popen([command], shell=True, stdout=PIPE, stderr=PIPE)
    out, err = proc.communicate();

    if proc.returncode != 0:
        msg = "Error: Unable to find api server, rc was " + str(proc.returncode)
        if LOGGER:
            LOGGER.error(msg)
        raise Exception(msg)

    # cf api output comes back in the form:
    # API endpoint: https://api.ng.bluemix.net (API version: 2.23.0)
    # so take out just the part we need
    words = out.split()
    for word in words:
        if word.startswith("https://"):
            cf_api_server=word
    # get ice server as well by adjusting cf server
    ice_api_server = cf_api_server
    ice_api_server = ice_api_server.replace ( 'api.', 'containers-api.')
    if DEBUG=="1":
        if LOGGER:
            LOGGER.debug("cf_api_server set to " + str(cf_api_server))
            LOGGER.debug("ice_api_server set to " + str(ice_api_server))

    return cf_api_server, ice_api_server


# return the remaining time to wait
# first time, will prime from env var and subtract init script time 
#
# return is the expected max time left in seconds we're allowed to wait
# for pending jobs to complete
def get_remaining_wait_time (first = False):
    global FULL_WAIT_TIME
    if first:
        # first time through, set up the var from env
        try:
            FULL_WAIT_TIME = int(os.getenv('WAIT_TIME', "5"))
        except ValueError:
            FULL_WAIT_TIME = 5

        # convert to seconds
        time_to_wait = FULL_WAIT_TIME * 60

        # and (if not 0) subtract out init time
        if time_to_wait != 0:
            try:
                initTime = int(os.getenv("INT_EST_TIME", "0"))
            except ValueError:
                initTime = 0

            time_to_wait -= initTime
    else:
        # just get the initial start time
        time_to_wait = WAIT_TIME

    # if no time to wait, no point subtracting anything
    if time_to_wait != 0:
        time_so_far = int(timeit.default_timer() - SCRIPT_START_TIME)
        time_to_wait -= time_so_far

    # can't wait negative time, fix it
    if time_to_wait < 0:
        time_to_wait = 0

    return time_to_wait

# find the given service in our space, get its service name, or None
# if it's not there yet
def find_service_name_in_space (service):
    command = "cf services"
    proc = Popen([command], shell=True, stdout=PIPE, stderr=PIPE)
    out, err = proc.communicate();

    if proc.returncode != 0:
        LOGGER.info("Unable to lookup services, error was: " + out)
        return None

    foundHeader = False
    serviceStart = -1
    serviceEnd = -1
    serviceName = None
    for line in out.splitlines():
        if (foundHeader == False) and (line.startswith("name")):
            # this is the header bar, find out the spacing to parse later
            # header is of the format:
            #name          service      plan   bound apps    last operation
            # and the spacing is maintained for following lines
            serviceStart = line.find("service")
            serviceEnd = line.find("plan")-1
            foundHeader = True
        elif foundHeader:
            # have found the headers, looking for our service
            if service in line:
                # maybe found it, double check by making
                # sure the service is in the right place,
                # assuming we can check it
                if (serviceStart > 0) and (serviceEnd > 0):
                    if service in line[serviceStart:serviceEnd]:
                        # this is the correct line - find the bound app(s)
                        # if there are any
                        serviceName = line[:serviceStart]
                        serviceName = serviceName.strip()
        else:
            continue

    return serviceName

# find a service in our space, and if it's there, get the dashboard
# url for user info on it
def find_service_dashboard (service):

    serviceName = find_service_name_in_space(service)
    if serviceName == None:
        return None

    command = "cf service \"" + serviceName + "\""
    proc = Popen([command], shell=True, stdout=PIPE, stderr=PIPE)
    out, err = proc.communicate();

    if proc.returncode != 0:
        return None

    serviceURL = None
    for line in out.splitlines():
        if line.startswith("Dashboard: "):
            serviceURL = line[11:]
        else:
            continue

    return serviceURL

# search cf, find an app in our space bound to the given service, and return
# the app name if found, or None if not
def find_bound_app_for_service (service):

    proc = Popen(["cf services"], shell=True, stdout=PIPE, stderr=PIPE)
    out, err = proc.communicate();

    if proc.returncode != 0:
        return None

    foundHeader = False
    serviceStart = -1
    serviceEnd = -1
    boundStart = -1
    boundEnd = -1
    boundApp = None
    for line in out.splitlines():
        if (foundHeader == False) and (line.startswith("name")):
            # this is the header bar, find out the spacing to parse later
            # header is of the format:
            #name          service      plan   bound apps    last operation
            # and the spacing is maintained for following lines
            serviceStart = line.find("service")
            serviceEnd = line.find("plan")-1
            boundStart = line.find("bound apps")
            boundEnd = line.find("last operation")
            foundHeader = True
        elif foundHeader:
            # have found the headers, looking for our service
            if service in line:
                # maybe found it, double check by making
                # sure the service is in the right place,
                # assuming we can check it
                if (serviceStart > 0) and (serviceEnd > 0) and (boundStart > 0) and (boundEnd > 0):
                    if service in line[serviceStart:serviceEnd]:
                        # this is the correct line - find the bound app(s)
                        # if there are any
                        boundApp = line[boundStart:boundEnd]
        else:
            continue

    # if we found a binding, make sure we only care about the first one
    if boundApp != None:
        if boundApp.find(",") >=0 :
            boundApp = boundApp[:boundApp.find(",")]
        boundApp = boundApp.strip()
        if boundApp=="":
            boundApp = None

    if DEBUG:
        if boundApp == None:
            LOGGER.debug("No existing apps found bound to service \"" + service + "\"")
        else:
            LOGGER.debug("Found existing service \"" + boundApp + "\" bound to service \"" + service + "\"")

    return boundApp

# look for our default bridge app.  if it's not there, create it
def check_and_create_bridge_app ():
    # first look to see if the bridge app already exists
    command = "cf apps"
    LOGGER.debug("Executing command \"" + command + "\"")
    proc = Popen([command], shell=True, stdout=PIPE, stderr=PIPE)
    out, err = proc.communicate();

    if DEBUG:
        LOGGER.debug("command \"" + command + "\" returned with rc=" + str(proc.returncode))
        LOGGER.debug("\tstdout was " + out)
        LOGGER.debug("\tstderr was " + err)

    if proc.returncode != 0:
        return None

    for line in out.splitlines():
        if line.startswith(DEFAULT_BRIDGEAPP_NAME + " "):
            # found it!
            return True

    # our bridge app isn't around, create it
    LOGGER.info("Bridge app does not exist, attempting to create it")
    if os.environ.get('OLDCF_LOCATION'):
        command = os.environ.get('OLDCF_LOCATION')
        if not os.path.isfile(command):
            command = 'cf'
    else:
        command = 'cf'
    command = command +" push " + DEFAULT_BRIDGEAPP_NAME + " -i 1 -d mybluemix.net -k 1M -m 64M --no-hostname --no-manifest --no-route --no-start"
    LOGGER.debug("Executing command \"" + command + "\"")
    proc = Popen([command], shell=True, stdout=PIPE, stderr=PIPE)
    out, err = proc.communicate();

    if DEBUG:
        LOGGER.debug("command \"" + command + "\" returned with rc=" + str(proc.returncode))
        LOGGER.debug("\tstdout was " + out)
        LOGGER.debug("\tstderr was " + err)

    if proc.returncode != 0:
        LOGGER.info("Unable to create bridge app, error was: " + out)
        return False

    return True


# look for our bridge app to bind this service to.  If it's not there,
# attempt to create it.  Then bind the service to that app under the 
# given plan.  If it all works, return that app name as the bound app
def create_bound_app_for_service (service, plan=DEFAULT_SERVICE_PLAN):

    if not check_and_create_bridge_app():
        return None

    # get or create the service if necessary
    serviceName = get_or_create_service(service, plan)

    if serviceName is None:
        return None

    # now try to bind the service to our bridge app
    LOGGER.info("Binding service \"" + serviceName + "\" to app \"" + DEFAULT_BRIDGEAPP_NAME + "\"")
    proc = Popen(["cf bind-service " + DEFAULT_BRIDGEAPP_NAME + " \"" + serviceName + "\""], 
                 shell=True, stdout=PIPE, stderr=PIPE)
    out, err = proc.communicate();

    if proc.returncode != 0:
        LOGGER.info("Unable to bind service to the bridge app, error was: " + out)
        return None

    return DEFAULT_BRIDGEAPP_NAME

# get or create the service and bind it to app
# Returns app when bound to service, None if there is an error
def bind_app_to_service (app, service, plan=DEFAULT_SERVICE_PLAN):
    # get or create the service if necessary
    serviceName = get_or_create_service(service, plan)

    if serviceName is None:
        return None
        
    #Doing a bind-service on an already bound service results in return code 0 and a no-op.
    #  it is quicker to do it this way than to check if the service is already bound
    LOGGER.info("Binding service \"" + serviceName + "\" to app \"" + app + "\"")
    proc = Popen(["cf bind-service \"" + app + "\" \"" + serviceName + "\""], 
                 shell=True, stdout=PIPE, stderr=PIPE)
    out, err = proc.communicate();
    #We do not restart the app, but we can still access the VCAP variables using cf calls.
    if proc.returncode != 0:
        LOGGER.info("Unable to bind service to the app, error was: " + out)
        return None
    return app

# return the service name for the service, if the service doesn't exist, create it.
def get_or_create_service(service, plan=DEFAULT_SERVICE_PLAN):
    serviceName = find_service_name_in_space(service)

    # if we don't have the service name, means the tile isn't created in our space, so go
    # load it into our space if possible
    if serviceName == None:
        LOGGER.info("Service \"" + service + "\" is not loaded in this space, attempting to load it")
        serviceName = service
        command = "cf create-service \"" + service + "\" \"" + plan + "\" \"" + serviceName + "\""
        LOGGER.debug("Executing command \"" + command + "\"")
        proc = Popen([command],
                     shell=True, stdout=PIPE, stderr=PIPE)
        out, err = proc.communicate();

        if proc.returncode != 0:
            LOGGER.info("Unable to create service in this space, error was: " + out)
            return None

    return serviceName


# find given bound app, and look for the passed bound service in cf.  once
# found in VCAP_SERVICES, look for the credentials setting, and return the
# dict.  Raises Exception on errors
def get_credentials_from_bound_app (service, binding_app=None, plan=DEFAULT_SERVICE_PLAN):
    # if no binding app parm passed, go looking to find a bound app for this one
    if binding_app == None:
        binding_app = find_bound_app_for_service(service)
        # if still no binding app, and the user agreed, CREATE IT!
        if binding_app == None:
            setupSpace = os.environ.get('SETUP_SERVICE_SPACE')
            if (setupSpace != None) and (setupSpace.lower() == "true"):
                binding_app = create_bound_app_for_service(service=service, plan=plan)
            else:
                raise Exception("Service \"" + service + "\" is not loaded and bound in this space.  " + LABEL_COLOR + "Please add the service to the space and bind it to an app, or set the parameter to allow the space to be setup automatically" + LABEL_NO_COLOR)
    else:
        setupSpace = os.environ.get('SETUP_SERVICE_SPACE')
        if (setupSpace != None) and (setupSpace.lower() == "true"):
            #Make sure provided binding_app is bound to the service
            binding_app = bind_app_to_service(app=binding_app, service=service, plan=plan)


    # if STILL no binding app, we're out of options, just fail out
    if binding_app == None:
        raise Exception("Unable to access an app bound to the " + service + " service - this must be set to get the proper credentials.")

        
    # try to read the env vars off the bound app in cloud foundry, the one we
    # care about is "VCAP_SERVICES"
    verProc = Popen(["cf env \"" + binding_app + "\""], shell=True, 
                    stdout=PIPE, stderr=PIPE)
    verOut, verErr = verProc.communicate();

    if verProc.returncode != 0:
        raise Exception("Unable to read credential information off the app bound to the " + service + " service - please check that it is set correctly.")

    envList = []
    envIndex = 0
    inSection = False
    # the cf env var data comes back in the form
    # blah blah blah
    # {
    #    <some json data for a var>
    # }
    # ... repeat, possibly including blah blah blah
    #
    # parse through it, and extract out just the json blocks
    for line in verOut.splitlines():
        if inSection:
            envList[envIndex] += line
            if line.startswith("}"):
                # block end
                inSection = False
                envIndex = envIndex+1
        elif line.startswith("{"): 
            # starting a block
            envList.append(line)
            inSection = True
        else:
            # just ignore this line
            pass

    # now parse that collected json data to get the actual vars
    jsonEnvList = {}
    for x in envList:
        jsonEnvList.update(json.loads(x))

    return_cred_list = []
    found = False

    # find the credentials for the service in question
    if jsonEnvList != None:
        serviceList = jsonEnvList['VCAP_SERVICES']
        if serviceList != None:
            analyzerService = serviceList[service]
            if analyzerService != None:
                credentials = analyzerService[0]['credentials']
                if credentials != None:
                    found = True
                    return credentials

    if not found:
        raise Exception("Unable to get bound credentials for access to the " + service + " service.")

    return None


# retrieve the credentials for non-binding service brokers which (optionally) implement the service_keys endpoint
def get_credentials_for_non_binding_service(service, plan=DEFAULT_SERVICE_PLAN, key_name=DEFAULT_SERVICE_KEY):
    # get or create the service if allowed
    setupSpace = os.environ.get('SETUP_SERVICE_SPACE')
    if (setupSpace != None) and (setupSpace.lower() == "true"):
        service_name = get_or_create_service(service, plan)
    else:
        service_name = find_service_name_in_space(service)
    if service_name is None:
        return None

    result = execute_cf_cmd("cf service-keys '%s'" % service_name)
    debug("Raw result: \n" + str(result))
    # ignore the header and grab the first service key
    result = result.splitlines()[3:4:]
    debug("Raw filtered result: \n" + str(result))
    
    if len(result) == 0:
        #create the default service key
        execute_cf_cmd("cf csk '%s' '%s'" % (service_name, key_name))
        result = execute_cf_cmd("cf service-keys '%s'" % service_name)
        debug("Raw result: \n" + str(result))
        # ignore the header and grab the first service key
        result = result.splitlines()[3:4:]
        debug("Raw filtered result: \n" + str(result))

    if len(result) > 0:
        result = execute_cf_cmd("cf service-key '%s' '%s'" % (service_name, result[0].strip()))
        debug("Raw result: \n" + str(result))
        # extract out only the json portion of the command result
        result = '\n'.join(result.split('\n')[1:-1])
        debug("Raw filtered result: \n" + str(result))

        result = json.loads(result)
        debug("JSON result: \n" + str(result))

        # return the json as-is, let the caller pull the appropriate data out (which may vary from one service broker
        # to another)
        return result
    else:
        LOGGER.error("No service key for service instance %s", service_name)

    return None


def execute_cf_cmd(command):
    proc = Popen([command], shell=True, stdout=PIPE, stderr=PIPE)
    out, err = proc.communicate()

    debug("Executing command \"%s\" \n%s" % (command, out))

    if proc.returncode != 0:
        LOGGER.error("An error occurred running command '%s' " + out % command)
        return None

    return out


def debug(message):
    if DEBUG:
        LOGGER.debug(message)


