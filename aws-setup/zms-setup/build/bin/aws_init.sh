#!/bin/bash

# Exposes bucket names based on account and region
#   ENV
#   ZMS_DATA_BUCKET_NAME
#   ZMS_AUDIT_LOG_BUCKET_NAME
#   REGION
#   TRUST_STORE_PATH
#   JDK_CA_CERTS_PATH
#   KEY_STORE_PATH
#   JDK_CA_CERTS_PWD
#   RDS_MASTER
#   RDS_REPLICA

set -e

export REGION=`curl http://169.254.169.254/latest/dynamic/instance-identity/document|grep region|awk -F\" '{print $4}'`
export ENV="dev"

export ZMS_DATA_BUCKET_NAME="test-athenz-zms-data-dev-us-west-2"
export ZMS_AUDIT_LOG_BUCKET_NAME="test-athenz-audit-log-dev-us-west-2"
export TRUST_STORE_PATH="/opt/zms/conf/zms_java_truststore.jks"
export ZMS_TRUST_STORE_PATH="/opt/zms/conf/zms_truststore.jks"
export JDK_CA_CERTS_PATH="/etc/alternatives/jre_1.8.0_openjdk/lib/security/cacerts"
export KEY_STORE_PATH="/opt/zms/conf/zms_keystore.pkcs12"
export JDK_CA_CERTS_PWD="changeit"
export RDS_MASTER="zmsrds-databasecluster-fh8auoygcvvm.cluster-c3vq7hmabid9.us-west-2.rds.amazonaws.com"

