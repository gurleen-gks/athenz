# Setup ZTS on AWS
-------------------
- [AWS Resource Setup](###-aws-resource-setup)
    - [IAM role setup](####-iam-role-setup)
    - [S3 bucket for ELB logs](####-s3-bucket-for-elb-logs)
    - [VPC setup](####-vpc-setup)
    - [RDS Setup](####-rds-setup)
         - [Create Aurora Mysql cluster](#####-create-an-aurora-mysql-cluster)
         - [Schema setup](#####-set-up-the-schema)
    - [S3 bucket for zts data](####-create-s3-bucket-to-store-zts-data)    
         - [Generate and upload service private key](#####-generate-and-upload-service-private-key)
         - [Upload server X.509 cert and key](#####-upload-server-x.509-cert-and-key)
         - [Upload truststore password](#####-upload-truststore-password) 
         - [Upload ZMS DB User Password](#####-upload-zts-db-user-password)
    - [Update Policy for S3 Bucket for Audit logs](####-create-s3-bucket-for-audit-logs)
    - [Edit Variables & Properties](####-edit-variables-&-properties)
        - [aws_init.sh](#####-edit-aws_init.sh)
        - [zts.properties](#####-edit-the-zts.properties-file)
             - [Database](######-database)
             - [User Authentication](######-user-authentication)
             - [Domain Admins](######-domain-admins)
        - [athenz.properties](#####-edit-athenz.properties-file)
    - [Packer](####-packer)
        - [Packer VPC setup](#####-packer-vpc-setup)
        - [Build ZMS Image](#####-build-zts-image)
    - [Deploy ZMS](####deploy-zts) 

## AWS Resource Setup
-------------

### IAM role setup
-- 
Create EC2 profile role for zts using cloudformation [template](https://github.com/yahoo/athenz/blob/master/aws-setup/zts-setup/cloud-formation/athens-zts-aws-roles-setup.yaml). This template creates a role named `athenz.zts-service`

### VPC Setup
--
Setup VPC using the cloudformation [template](https://github.com/yahoo/athenz/blob/master/aws-setup/zts-setup/cloud-formation/athens-zts-aws-resource-setup.yaml) and set the following mandatory parameters
- `Route53HostedZoneName`	
- `Route53RecordName`
- `S3AccessLogBucketName`(Created during Zms Setup)
- `Environment`

The other parameters are set by default. Change them as per your requirement

*NOTE - Modifying the other defaults might require subsequent changes.*

Following resources will be created after executing the template
1. 2 availability zones
1. public & private subnets for zts in each availability zone
1. public & private subnets for cert signer in each availability zone
1. 4 NAT gateways and elastic IPs
1. NACL for the subnets
1. Internet gateways for all public subnets
1. Route tables for all subnets
1. Elastic load balancer
1. Route 53 DNS entry
1. ZTS server & ELB security groups

### RDS Setup
--
#### Create an Aurora MySQL cluster
--
Use the cloudformation[template](https://github.com/yahoo/athenz/blob/master/aws-setup/zts-setup/cloud-formation/athens-zts-aws-rds-setup.yaml) template to create it by filling in the mandatory parameters

- `Route53HostedZoneName`	
- `Route53RecordName`
- `DatabaseUsername`
- `DatabasePassword`
- `Environment`

The other parameters are set by default. Change them as per your requirement

#### Set up the schema
--
1. Create an instance in private subnet and login into it.
After logging in, use the following commands to connect to the cluster using Database Root Credentials
    ```
    > mysql -h &lt;RDS_CLSUTER_ENDPOINT&gt; -P 3306 -u &lt;DB_USER&gt; -p
    ``` 
1. Copy the [zts_server.sql](https://github.com/yahoo/athenz/blob/master/servers/zts/schema/zts_server.sql) file from the Athenz Git repository onto this host and create the database using the following command
    ```
    > mysql -h &lt;RDS_CLSUTER_ENDPOINT&gt; -P 3306 -u &lt;DB_USER&gt; -p  < zts_server.sql
    ```
1. Create a user with full privileges on zms database created above. Foe eg. If your ZMS Server will be running on zts1.athenz.com and user to be created is `athenz-zts` having password `athenz-zts` 
    ```
    > CREATE USER 'athenz-zts'@'zts1.athenz.com' IDENTIFIED BY 'athenz-zts';
    > GRANT ALL PRIVILEGES ON zts_store TO 'athenz-zts'@'zts1.athenz.com';
    ```

### Create S3 bucket to store zms data
--------------------------------------

Create S3 bucket for storing zts certificates & keys with appropriate policy as follows
```	
{
"Version": "2012-10-17",
"Statement": [ 
    {
        "Sid": "",
        "Effect": "Allow",
        "Principal": {
            "AWS": "arn:aws:iam::149134300625:role/athenz.zts-service"
        },
        "Action": "s3:GetObject",
        "Resource": "arn:aws:s3::: <bucket-name> /*"
    }
    ]
}
```
Also enable Default Encryption for your bucket.

*NOTE - athenz.zts-service is the EC2 role created using IAM template above* 

#### Generate and upload service private key and id
--
Generate a unique private key that ZTS Server will use to sign any NTokens it issues 
```
openssl genrsa -out service_private_key 2048
openssl rsa -in service_private_key -pubout > zts_service_x509_key_public
```
Upload the service private key with name `service_private_key` onto the s3 bucket

Upload the service private key id with name service_private_key_id onto the s3 bucket. This file just contains
the id of private_key. This file is not mandatory as the id defaults to `0` if not specified 
    
#### Upload server X.509 cert and key
--
*NOTE - While it is still possible to generate and use a self-signed X509 certificate for ZMS Servers, it is recommended to purchase one for your production server from a well known certificate authority. Having such a certificate installed on your ZMS Servers will no longer require to distribute the server's CA certificate to other hosts (e.g. ZTS Servers, Hosts running ZPU).*
- Follow the instructions provided by the Certificate Authority that you're going to purchase your certificate from, to generate your private key and Certificate Request (CSR).
- If you are using self signed certs then run the following commands:
    ```
    openssl genrsa -des3 -out zts_ca_key 4096 (Create Zts Ca Key)
    openssl req -x509 -new -nodes -key zts_ca_key -sha256 -days 1024 -out service_x509_ca_certs  (Generate Ca key)
    openssl genrsa -out service_x509_key 2048  (Generate your private key))
    openssl req -new -key service_x509_key -out service_x509_csr  (Generate your CSR)
    openssl x509 -req -in service_x509_csr -CA service_x509_ca_certs -CAkey zts_ca_key -CAcreateserial -out service_x509_cert -days 500 -sha256  (Generate your Certificate)
    ```
- Verify your certs
    ```
    openssl x509 -in service_x509_ca_certs -text -noout
    openssl x509 -in service_x509_cert -text -noout
    ```
- Once you have received your X509 certificate and key, 
    - Upload the certificate with on s3 bucket with name `service_x509_cert` 
    - Upload the private key with name `service_x509_key`
    - Upload the Root CA cert with name `service_x509_ca_certs`

#### Upload RDS CA Certs
---
- Upload the RDS CA Certs with key `service_rds_ca_certs` 
For details on AWS RDS Certs, Please refer [RDS CERTS AWS](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/UsingWithRDS.SSL.html)

#### Upload truststore password
--
- Upload password you want to use for truststore with name `service_x509_store_pwd`

#### Upload ZTS DB User Password
--
- Create a file containing only the password for ZTS Database user(`athenz-zts`) created above during RDS schema setup
- Upload the file to bucket with name `db_user_data`

#### Upload ZMS CA Certs

- Since ZMS CA Cert with key `zms_service_x509_ca_certs`. They will be added to ZTS truststore so that ZTS can communicate securely with ZMS

#### Upload ZTS and ZMS Public keys

- Upload ZTS public key with name `zts_service_x509_key_public.pem `
- Upload ZMS public key with name `zms_service_x509_key_public.pem `

They are required to generate athenz.conf file at `/opt/zts/conf` to include the ZTS Server URL 
and the registered public keys that the athenz client libraries and utilities will 
use to establish connection and validate any data signed by the ZTS Server:

### Update the  policy for S3 bucket for ELB logs

Update the bucket policy for S3 bucket created for audit logs during zms setup to allow `athenz.zts-service` 
role to read and write to it.

```
{
"Version": "2012-10-17",
"Statement": [
    {
        "Sid": "",
        "Effect": "Allow",
        "Principal": {
            "AWS": [
                "arn:aws:iam::488664618023:role/athenz.zms-service"
                "arn:aws:iam::488664618023:role/athenz.zts-service"
            ]
        },
        ...
]
}
```
### Update ZMS DATA BUCKET

- Upload zts service public key to ZMS Data Bucket with key `zts_service_x509_key_public.pem`

### Register ZTS Service
In order for ZTS to access ZMS domain data, it must identify itself
as a registered service in ZMS. Use `zms-cli` utility to 
register a new service in `sys.auth` domain. If ZMS Servers are 
running with a X509 certificate from a well know certificate 
authority (not a self-signed one) we don't need to reference the CA
cert like we are doing below for self signed certs.

Login into your zms-server instance as domain admin you created during zms setup and run the below commands:

```
- Download ZMS CA Certs(If using self signed certs)
    aws s3 cp s3://athenz-zms-data-bucket-us-west-2/zms_service_x509_ca_certs /tmp/zms_service_x509_ca_certs
- Download ZTS public key
    aws s3 cp s3:// athenz-zms-data-bucket-us-west-2/zts_service_x509_key_public.pem/tmp/zts_service_x509_key_public.pem
- Register Service using zms-cli
- ./opt/zts/bin/zms-cli -c /tmp/service_x509_ca_certs -z <zms_url> -d sys.auth add-service zts 0 /tmp/zts_service_x509_key_public.pem
```
*NOTE - Append /zms/v1 to your url in the command above*

For e.g. If your zms server is running at https://athenz.zms.com:4443 then pass `https://athenz.zms.com:4443/zms/v1`.

### Edit Variables & Properties
--
#### Edit aws_init.sh
-- 
Update the bucket names in `athenz/aws-setup/zts-setup/build/bin/aws_init.sh` by editing the below lines
```
export ZTS_DATA_BUCKET_NAME="&lt;The name of your zts data bucket&gt;"
export ZTS_AUDIT_LOG_BUCKET_NAME="&lt;The name of your zms audit data bucket&gt;"
export ZMS_DATA_BUCKET_NAME="&lt;The name of your zms data bucket&gt;"
export ZTS_URL="&lt;zts_url&gt;"
export ZMS_URL=""&lt;zms_url&gt;"
export RDS_MASTER="&lt;zts-rds-databasecluster-endpoint&gt;"
```
The other variables are for trust store & key store setup. We recommend to use the defaults but if you change then update the corresponding values in `athenz.properties` file discussed later.

#### Edit the zts.properties file
-- 

##### Database Access
--
Modify the following settings if RDS username & RDS password filename (stored on S3) are different from defaults suggested above.
```
athenz.zts.cert_record_store_factory_class=com.yahoo.athenz.zts.cert.impl.JDBCCertRecordStoreFactory
athenz.zts.cert_jdbc_user=athenz-zts
athenz.zts.cert_jdbc_password=db_user_data
```

##### Athenz CA X.509 Certificate Issuing
--
For authenticating services using X509 certificates, ZTS Servers expect the configured cert signer factory class names in its athenz.zts.cert_signer_factory_class system property. Self Cert Signer com.yahoo.athenz.zts.cert.impl.SelfCertSignerFactory is a sample implementation of cert Signer we have for development environment.
You can use SelfCertSigner or have your implementation of Cert Signer.
Uncomment and modify the following lines in zts.properties file if using Self Cert Signer

```
athenz.zms.object_store_factory_class=com.yahoo.athenz.zms.store.impl.JDBCObjectStoreFactory
athenz.zms.jdbc_user=athenz-zts
athenz.zms.jdbc_password=db_user_data
```

#### Truststore & Keystore Settings
--
- If you modified the truststore and keystore paths and password in the `aws_init.sh` file then change the below settings in `athenz.properties` file    
  - `athenz.ssl_key_store=/opt/zts/conf/zts_keystore.pkcs12`  `//path to the keystore file that contains the server's certificate`
  - `athenz.ssl_key_store_type=PKCS12`    `//specifies the type for the keystore specified in the`
  - `athenz.ssl_key_store_password=service_x509_store_pwd`    `//S3 bucket  key name for Password for the keystore specified in the athenz.ssl_key_store property`
  - `athenz.ssl_trust_store=/opt/zts/conf/zts_truststore.jks`     `//path to the trust store file that contains CA certificates trusted by this Jetty instance`
  - `athenz.ssl_trust_store_type=JKS`     `//specifies the type for the truststore specified`
  - `athenz.ssl_trust_store_password=service_x509_store_pwd`      `//password for the truststore`  

- Update the foolowing in zms.properties file
  - `athenz.zts.ssl_key_store=/opt/zts/conf/zts_keystore.pkcs12`  `//path to the keystore file that contains the server's certificate`
  - `athenz.zts.ssl_key_store_type=PKCS12`    `//specifies the type for the keystore specified in the`
  - `athenz.zts.ssl_key_store_password=service_x509_store_pwd`    `//S3 bucket  key name for Password for the keystore specified in the athenz.ssl_key_store property`
  - `athenz.zts.ssl_trust_store=/opt/zts/conf/zts_truststore.jks`     `//path to the trust store file that contains CA certificates trusted by this Jetty instance`
  - `athenz.zts.ssl_trust_store_type=JKS`     `//specifies the type for the truststore specified`
  - `athenz.zts.ssl_trust_store_password=service_x509_store_pwd`      `//password for the truststore` 

### Packer
--
#### Packer VPC Setup

Packer VPC was set during zms setup, update `packer.json` accordingly.
```
&lt;aws-region where you created the resources&gt;
{
   "subnet_id":"&lt;packer_public_subnet_id&gt;",
   "vpc_id": "&lt;vpc_id&gt;",
   "aws_region": "&lt;aws-region where you created the resources&gt;",
   "aws_ami_name": "zts-aws-cd-image",
   "aws_access_key": "{{env `AWS_ACCESS_KEY_ID`}}",
   "aws_secret_key": "{{env `AWS_SECRET_ACCESS_KEY`}}",
   "aws_session_token": "{{env `AWS_SESSION_TOKEN`}}",
   "ssh_keypair_name":"&lt;EC2_SSH_Key_Name&gt;",
   "ssh_private_key_file":"&lt;PATH_TO_SSH_KEYPAIR&gt;",
   "source_ami": "ami-02c71d7a"
}
```

#### Build ZTS image
--
Build the image with packer using the following command 

`packer build packer/aws/packer.json`

### Deploy ZTS
--
Run cloud formation [template](https://github.com/yahoo/athenz/blob/master/aws-setup/zts-setup/cloud-formation/athenz-zts-aws-instance-deployment.yaml) to bring up the zts-instances in 2 availability zones.
- The imageID parameter should be set to the image created in above step.

The ZMS Server is now up and running.

