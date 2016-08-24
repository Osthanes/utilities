import time
import subprocess
import os

def before_feature(context, feature):
    print("The following environment variables must be exported before running: GROUP_NAME, IMGNAME, HOSTNAME, DOMAIN, PORT")
    print("The image, $IMGNAME, must export a single port, which must be $PORT")
    assert os.environ["GROUP_NAME"]
    assert os.environ["IMGNAME"]
    assert os.environ["HOSTNAME"]
    assert os.environ["DOMAIN"]
    assert os.environ["PORT"]

def after_scenario(context, scenario):
    if context.groupName:
        try:
            print(subprocess.check_output("cf ic group rm --force "+context.groupName, shell=True))
            time.sleep(10)
        except subprocess.CalledProcessError as e:
            print (e.cmd)
            print (e.output)
            raise e