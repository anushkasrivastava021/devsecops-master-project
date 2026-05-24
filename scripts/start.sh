#!/bin/bash
# Navigate to the folder where CodeDeploy dropped the files
cd /home/ec2-user/server-monitor

# Install the required Python libraries
pip3 install -r requirements.txt

# Start the Flask app in the background (nohup ensures it stays running after deployment finishes)
nohup python3 main.py > app.log 2>&1 &