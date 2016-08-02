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


python_utils.LOGGER = python_utils.setup_logging()

BEARER_TOKEN, SPACE_GUID = python_utils.load_cf_auth_info()
CF_API_SERVER, CCS_API_SERVER = python_utils.find_api_servers()

python_utils.LOGGER.info("Starting python create group")
python_utils.LOGGER.debug("Servers cf: %s, ccs: %s" %(CF_API_SERVER, CCS_API_SERVER))

sizes = { 64, 128, 256, 512, 1024, 2048, 4096, 8192, 16384 }

