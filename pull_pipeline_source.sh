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
echo "cloning extension repositories"
if [ -d update_service ]; then cd update_service; git pull; cd ..; else git clone  --depth 1 https://github.com/Osthanes/update_service.git;fi 
if [ -d appscan_dynamic_analyzer ]; then cd appscan_dynamic_analyzer; echo "updating Language_en.properties"; git checkout -f Language_en.properties; cd ..; else git clone  --depth 1  https://github.com/Osthanes/appscan_dynamic_analyzer.git; fi
if [ -d notifications ]; then cd notifications; echo "updating Language_en.properties"; git checkout -f Language_en.properties; cd ..; else git clone  --depth 1 https://github.com/Osthanes/notifications.git ; fi
if [ -d globalization ]; then cd globalization; echo "updating Language_en.properties"; git checkout -f Language_en.properties; cd ..; else git clone  --depth 1 https://github.com/Osthanes/globalization.git ; fi
if [ -d appscan_static_analyzer ]; then cd appscan_static_analyzer; echo "updating Language_en.properties"; git checkout -f Language_en.properties; cd ..; else git clone  --depth 1 https://github.com/Osthanes/appscan_static_analyzer.git ; fi
if [ -d docker_builder ]; then cd docker_builder; echo "updating Language_en.properties"; git checkout -f Language_en.properties; cd ..; else git clone  --depth 1 https://github.com/Osthanes/docker_builder.git ; fi 
if [ -d container_deployer ]; then cd container_deployer; echo "updating Language_en.properties"; git checkout -f Language_en.properties; cd ..; else git clone  --depth 1 https://github.com/Osthanes/container_deployer ; fi

echo "packaging up en source files to: osthanes_en_source_files.tar"
find . -name "Language_en.properties"  | tar -cf osthanes_en_source_files.tar -T -
tar --list --file osthanes_en_source_files.tar 





