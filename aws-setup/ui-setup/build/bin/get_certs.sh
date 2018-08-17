#!/usr/bin/env bash

# download server cert and key from private s3 bucket
# aws s3 client will automatically decrypt the data

BUCKET_NAME=test-athenz-ui-data-bucket
KEY_FILE=service_x509_key
CERT_FILE=service_x509_cert

sudo mkdir -p /opt/ui/athenz-ui-bin/keys
aws s3 cp s3://$BUCKET_NAME/$KEY_FILE /opt/ui/athenz-ui-bin/keys/ui_key.pem
aws s3 cp s3://$BUCKET_NAME/$CERT_FILE /opt/ui/athenz-ui-bin/certs/ui_cert.pem