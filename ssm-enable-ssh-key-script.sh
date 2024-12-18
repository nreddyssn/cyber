#!/bin/bash
#
# Script that will transfer public key to AWS ec2 instance ~/.ssh/authorized_keys
# then complete a ssm connection over ssh.
# This script designed to be used as part of a ssh command leveraging ProxyCommand.
#
# See https://github.cicd.cloud.fpdev.io/pages/CPT/playbooks/edge/access for more information.

# Setting TIME_IN_SECONDS to default value
TIME_IN_SECONDS=60

# Get input arguments
HOST="$1"
USER="$2"
PORT="$3"
PUBLIC_KEY="$4"
[[ -n "$5" ]] && TIME_IN_SECONDS="$5"

# Exit if there is no -- separating instance and region
[[ "${HOST}" == *"--"* ]] || { echo "host does not have -- exit"; exit 1; }
AWS_REGION="${HOST##*--}"
HOST="${HOST%--*}"

# Get content of public key
PUBLIC_KEY_VALUE=$(<"${PUBLIC_KEY}")

# 1. Transfer public-key to server
# 2. Sleep for specified amount of time
# 3. Remove public-key from server
echo "Add public key to to instance ${HOST} authorized_keys for ${TIME_IN_SECONDS} seconds"
aws ssm send-command \
    --instance-ids "${HOST}" \
    --document-name "AWS-RunShellScript" \
    --comment "Add public key to instance authorized keys" \
    --parameters "commands=[\
    \"echo \\\"${PUBLIC_KEY_VALUE}\\\" >> /home/${USER}/.ssh/authorized_keys\",\
    \"sleep ${TIME_IN_SECONDS}\",\
    \"grep -v \\\"${PUBLIC_KEY_VALUE}\\\" /home/${USER}/.ssh/authorized_keys > /tmp/temp && mv /tmp/temp /home/${USER}/.ssh/authorized_keys\"\
    ]" \
    --region "${AWS_REGION}"

# Create an SSH session over SSM using the temporarily configured key
echo "Initiate start-session to instance ${HOST} in region ${AWS_REGION} via port ${PORT} over ssh"
aws ssm start-session \
    --target "${HOST}" \
    --region "${AWS_REGION}" \
    --document-name AWS-StartSSHSession \
    --parameters portNumber="${PORT}"
