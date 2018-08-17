#!/usr/bin/env bash
set -e

echo "========= Getting region and env from AWS ========="

REGION=$(curl http://169.254.169.254/latest/meta-data/placement/availability-zone | sed 's/.$//')
ENV="dev"

export _POD_DOMAIN_NAME="sys.auth"
export _POD_SERVICE_NAME="ui"
export ENVIRONMENT="${ENV}"
export REGION="${REGION}"
export UI_SERVER="<ui-server-host-name>"
export ZMS_SERVER="zms-server-host-name>"

echo "initializing aws cloudwatch log setup"
sudo python /opt/athenz-ui/awslogs-agent-setup.py -n -r $REGION -c /opt/athenz-ui/awslogs.conf

export -p | grep --extended-regex '^declare -x \<(USER|SHELL|_POD_DOMAIN_NAME|_POD_SERVICE_NAME|REGION|ENVIRONMENT)\>'

/bin/node /opt/ui/athenz-ui-bin/server.js