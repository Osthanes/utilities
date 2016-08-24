from behave import *
import subprocess
import os
import time
import re
import json

@given(u'Command {cmdString}')
def step_impl(context, cmdString):
    context.command=cmdString
    
@given(u'Parameter{param}')
def step_impl(context, param):
    context.command=context.command+param

@when(u'The command is run')
def step_impl(context):
    print (context.command)
    try:
        context.cmdOutput = subprocess.check_output(context.command, shell=True)
        print (context.cmdOutput)
    except subprocess.CalledProcessError as e:
        print (e.cmd)
        print (e.output)
        print
        raise e

@then(u'The group {grpName} is created')
def step_impl(context, grpName):
    context.groupName=grpName
    time.sleep(10)
    try:
        context.groupInfo = json.loads(subprocess.check_output("cf ic group inspect "+grpName, shell=True))
        print(context.groupInfo["Status"])
        while context.groupInfo["Status"] == "CREATE_IN_PROGRESS":
            time.sleep(20)
            try:
                context.groupInfo = json.loads(subprocess.check_output("cf ic group inspect "+grpName, shell=True))
                print(context.groupInfo["Status"])
            except subprocess.CalledProcessError as e:
                print (e.cmd)
                print (e.output)
                time.sleep(20)
                context.groupInfo = json.loads(subprocess.check_output("cf ic group inspect "+grpName, shell=True))
                print(context.groupInfo["Status"])
        print (json.dumps(context.groupInfo, sort_keys=True, indent=2))
    except subprocess.CalledProcessError as e:
        print (e.cmd)
        print (e.output)
        print
        raise e

@then(u'Value {parm} is {value}')
def step_impl(context, parm, value):
    if "$" in value:
        value = os.path.expandvars(value)
    assert str(context.groupInfo[parm]).upper() == value.upper()
    
@then(u'Child {parm} of {parent} is {value}')
def step_impl(context, parm, parent, value):
    if "$" in value:
        value = os.path.expandvars(value)
    assert str(context.groupInfo[parent][parm]).upper() == value.upper()
    
@then(u'List {parm} is empty')
def step_impl(context, parm):
    assert not context.groupInfo[parm]
    
@then(u'List {parm} contains {value}')
def step_impl(context, parm, value):
    if "$" in value:
        value = os.path.expandvars(value)
    assert value in context.groupInfo[parm]