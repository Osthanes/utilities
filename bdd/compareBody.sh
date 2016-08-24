#!/bin/bash
echo cf ic
cf ic -v group create "$@" | grep -o "Request body.*"
echo gp_create
../gp_create.py "$@" | grep -o "Request body.*"
