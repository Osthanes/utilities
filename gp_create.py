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

import json
import logging
import logging.handlers
import os
import os.path
import python_utils
import sys
import argparse
import requests


python_utils.LOGGER = python_utils.setup_logging()

def valid_size(string):
    sizes = [ 64, 128, 256, 512, 1024, 2048, 4096, 8192, 16384 ]
    value = int(string)
    if value in sizes:
        return value
    msg = "%r is not a valid memory size, valid sizes are: %r" % (string, sizes)
    raise argparse.ArgumentTypeError(msg)
    
def parse_bool(string):
    truth = { "True", "TRUE", "true", "1" }
    untruth = { "False", "FALSE", "false", "0" }
    if string in truth:
        return True
    elif string in untruth:
        return False
    else:
        msg = "%r is not a valid boolean" % string
        raise argparse.ArgumentTypeError(msg)
    
def build_data(args):
    numberInstances = { "Min", "Max", "Desired" }
    route = {"domain", "host"}
    onlyIncludeIfTrue = { "PublishAllPorts" }
    output = { "WorkingDir":"" }
    
    for arg in args:
        if arg in numberInstances:
            if not "NumberInstances" in output:
                output["NumberInstances"] = { }
            output["NumberInstances"][arg]=args[arg]
        elif arg in onlyIncludeIfTrue:
            if args[arg]:
                output[arg]="true"
        elif args[arg] is not None:
            if arg in route:
                if not "Route" in output:
                    output["Route"] = { }
                output["Route"][arg]=str(args[arg])
            if type(args[arg]) is bool:
                if args[arg]:
                    output[arg]="true"
                else:
                    output[arg]="false"
            else:
                output[arg]=args[arg]
    #perform NumberInstances calculations, default Min=1, Max=2, Desired=2
    if output["NumberInstances"]["Desired"]:
        if not output["NumberInstances"]["Min"]:
            output["NumberInstances"]["Min"]=1
        if not output["NumberInstances"]["Max"]:
            output["NumberInstances"]["Max"]=output["NumberInstances"]["Desired"] #By behavior of cf ic
    elif output["NumberInstances"]["Min"]: #min defined, desired not defined
        if not output["NumberInstances"]["Max"]:
            output["NumberInstances"]["Max"] = max(2, output["NumberInstances"]["Min"])
        output["NumberInstances"]["Desired"] = max(2, output["NumberInstances"]["Min"])
    elif output["NumberInstances"]["Max"]: #only max is defined
        output["NumberInstances"]["Min"]=1
        output["NumberInstances"]["Desired"]=min(2, output["NumberInstances"]["Max"])
    else:
        output["NumberInstances"]["Max"]=2
        output["NumberInstances"]["Min"]=1
        output["NumberInstances"]["Desired"]=2
    for arg in output["NumberInstances"]:
        output["NumberInstances"][arg]=str(output["NumberInstances"][arg])
    return output

parser = argparse.ArgumentParser()
parser.add_argument("--name", metavar="GROUP_NAME", required=True, dest="Name")
parser.add_argument("-m", "--memory", metavar="MEMORY_SIZE", type=valid_size, default=256, dest="Memory")
parser.add_argument("-n", "--hostname", metavar="HOSTNAME", dest="host")
parser.add_argument("-d", "--domain", metavar="DOMAIN")
parser.add_argument("-e", "--env", metavar="ENVIRONMENT_VARIABLE", action="append", dest="Env")
parser.add_argument("--env-file", metavar="ENVIRONMENT_VARIABLES_FILE", type=argparse.FileType('r'))
port_group = parser.add_mutually_exclusive_group()
port_group.add_argument("-p", "--publish", metavar="PORT", type=int, dest="Port")
port_group.add_argument("-P", action="store_true", dest="PublishAllPorts")
parser.add_argument("-v", "--volume", metavar="VOLUME_NAME", dest="Volumes", action="append")
parser.add_argument("--min", metavar="MIN_INSTANCE_COUNT", type=int, dest="Min")
parser.add_argument("--max", metavar="MAX_INSTANCE_COUNT", type=int, dest="Max")
parser.add_argument("--desired", metavar="DESIRED_INSTANCE_COUNT", type=int, dest="Desired")
parser.add_argument("--auto", action="store_true", dest="Autorecovery")
parser.add_argument("--anti", action="store_true", dest="AntiAffinity")
parser.add_argument("--session_affinity", action="store_true", dest="SessionAffinity")
parser.add_argument("--http_monitor_enabled", metavar="HTTP_MONITOR_ENABLED", nargs='?', const="true", default="true", type=parse_bool, dest="HTTP_MONITOR")
parser.add_argument("--http_monitor_path", metavar="HTTP_MONITOR_PATH", default="", dest="HTTP_MONITOR_PATH")
parser.add_argument("--http_monitor_rc_list", metavar="HTTP_MONITOR_RC_LIST", default="", dest="HTTP_MONITOR_RC_LIST")
parser.add_argument("--ip", metavar="IP_ADDRESS", dest="FloatingIpAddress")
parser.add_argument("Image", metavar="IMAGE_NAME")
parser.add_argument("Cmd", metavar="COMMAND", nargs="*")

args = vars(parser.parse_args())

BEARER_TOKEN, SPACE_GUID = python_utils.load_cf_auth_info()
CF_API_SERVER, CCS_API_SERVER = python_utils.find_api_servers()

python_utils.LOGGER.info("Starting python create group")

python_utils.LOGGER.debug("Servers cf: %s, ccs: %s" %(CF_API_SERVER, CCS_API_SERVER))

data = build_data(args)

python_utils.LOGGER.debug("Request body: %s" %(json.dumps(data, separators=(',', ':'), sort_keys=True)))
url = CCS_API_SERVER+":8443/v3/containers/groups"
headers = { 
    "Content-Type": "application/json",
    "Accept": "application/json",
    "X-Auth-Token": BEARER_TOKEN,
    "X-Auth-Project-Id": SPACE_GUID
}

response = requests.post(url, data=json.dumps(data), headers=headers)

if response.status_code >= 400:
    python_utils.LOGGER.error("Received %i status code from api server" %(response.status_code))
    python_utils.LOGGER.error(response.text)
    exit(1)
else:
    python_utils.LOGGER.debug("Received %i status code from api server" %(response.status_code))
    print response.text





