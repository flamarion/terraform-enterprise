#!/bin/bash

mv /etc/settings.json /etc/settings.json.bkp || true 
mv /etc/replicated.conf /etc/replicated.conf.bkp || true

cat > /etc/replicated.conf <<EOF
{
  "DaemonAuthenticationType": "password",
  "DaemonAuthenticationPassword": "${admin_password}",
  "TlsBootstrapType": "server-path",
  "TlsBootstrapHostname": "localhost",
  "TlsBootstrapCert": "/etc/localhost.crt",
  "TlsBootstrapKey": "/etc/localhost.key",
  "BypassPreflightChecks": true,
  "ImportSettingsFrom": "/etc/settings.json",
  "LicenseFileLocation": "/etc/license.rli",
  "ReleaseSequence": ${rel_seq}
}
EOF

cat > /etc/settings.json <<EOF
{
  "aws_access_key_id": {},
  "aws_instance_profile": {
    "value": "1"
  },
  "aws_secret_access_key": {},
  "azure_account_key": {},
  "azure_account_name": {},
  "azure_container": {},
  "azure_endpoint": {},
  "backup_token": {
    "value": "XHFJPTv7pnsq6EomEtONDWRcO0aweqws"
  },
  "ca_certs": {},
  "capacity_concurrency": {
    "value": "10"
  },
  "capacity_memory": {
    "value": "512"
  },
  "custom_image_tag": {
    "value": "hashicorp/build-worker:now"
  },
  "disk_path": {},
  "enable_metrics_collection": {
    "value": "1"
  },
  "enc_password": {
    "value": "${admin_password}"
  },
  "extern_vault_addr": {},
  "extern_vault_enable": {
    "value": "0"
  },
  "extern_vault_path": {},
  "extern_vault_propagate": {},
  "extern_vault_role_id": {},
  "extern_vault_secret_id": {},
  "extern_vault_token_renew": {},
  "extra_no_proxy": {},
  "gcs_bucket": {},
  "gcs_credentials": {
    "value": "{}"
  },
  "gcs_project": {},
  "hostname": {
    "value": "flamarion.hashicorp-success.com"
  },
  "iact_subnet_list": {},
  "iact_subnet_time_limit": {
    "value": "60"
  },
  "installation_type": {
    "value": "production"
  },
  "pg_dbname": {
    "value": "${db_name}"
  },
  "pg_extra_params": {},
  "pg_netloc": {
    "value" : "${db_host}:${db_port}"
  },
  "pg_password": {
    "value": "${db_pass}"
  },
  "pg_user": {
    "value": "${db_user}"
  },
  "placement": {
    "value": "placement_s3"
  },
  "production_type": {
    "value": "external"
  },
  "s3_bucket": {
    "value" : "${s3_bucket_name}"
  },
  "s3_endpoint": {},
  "s3_region": {
    "value": "${s3_region}"
  },
  "s3_sse": {},
  "s3_sse_kms_key_id": {},
  "tbw_image": {
    "value": "default_image"
  },
  "tls_vers": {
    "value": "tls_1_2_tls_1_3"
  }
}
EOF

curl -o /tmp/install.sh https://install.terraform.io/ptfe/stable
chmod +x /tmp/install.sh
/tmp/install.sh no-proxy private-address=$(curl http://169.254.169.254/latest/meta-data/local-ipv4) public-address=$(curl http://169.254.169.254/latest/meta-data/public-ipv4)
