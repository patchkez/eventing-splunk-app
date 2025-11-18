# Prerequisities
- podman
- access to AWS Route 53 service
- EC2 instance running with assigned public IP address and with active DNS zone e.g. `splunk1.example.com`
- open extra TCP port in security group which is attached to EC2 instance e.g. port `4000`

# Export environment variables
```
export WORK="${HOME}/projects/eventing-splunk-app"
export PASSWORD="changeme101"
export cert_host="splunk1.example.com"
```

# Create IAM Role + access keys in AWS IAM (TBD)
- this is a one time configuration

# Generare SSL/TLS certs on local machine
create secret file and name it `.route53.ini`:
```
[default]
aws_access_key_id = <aws_access_key_id>
aws_secret_access_key = <aws_secret_access_key>
```

# Prepare directories where certs will be stored
```
mkdir -p letsencrypt/etc
mkdir -p letsencrypt/lib
sudo rm -rf letsencrypt/etc/*
```

# Generate certificates and combine them
```
podman run -it --rm --name certbot -v .route53.ini:/root/.root53.ini -e AWS_CONFIG_FILE=/root/.root53.ini -v ${PWD}/letsencrypt/etc:/etc/letsencrypt -v ${PWD}/letsencrypt/lib:/var/lib/letsencrypt certbot/dns-route53:nightly certonly --dns-route53 -d ${cert_host}

cat letsencrypt/etc/archive/${cert_host}/privkey1.pem letsencrypt/etc/archive/${cert_host}/fullchain1.pem > letsencrypt/etc/archive/${cert_host}/combined.pem
```

# Start splunk container
Note: Adjust names of the certificates
```
podman run --rm  \
-p 8000:8000 \
-p 8088:8088 \
-v $WORK:/opt/work \
-v $WORK/letsencrypt/etc/archive/${cert_host}:/opt/splunk/certs \
-e "SPLUNK_START_ARGS=--accept-license" \
-e "SPLUNK_GENERAL_TERMS=--accept-sgt-current-at-splunk-com" \
-e "SPLUNK_PASSWORD=${PASSWORD}" \
-e "SPLUNK_HTTP_ENABLESSL=true" \
-e "SPLUNK_HTTP_ENABLESSL_CERT=/opt/splunk/certs/fullchain1.pem" \
-e "SPLUNK_HTTP_ENABLESSL_PRIVKEY=/opt/splunk/certs/privkey1.pem" \
-e "SPLUNKD_SSL_ENABLE=true" \
-e "SPLUNKD_SSL_CERT=/opt/splunk/certs/combined.pem" \
-e "SPLUNKD_SSL_CA=/opt/splunk/certs/chain1.pem" \
--name splunk splunk/splunk:latest
```

# Add kvstore config this to server.conf (TBD - extend playbook to have this automatically configured)
Once you see message:
```
Ansible playbook complete, will begin streaming splunkd_stderr.log
```
Connect to splunk container:
```
podman exec --user 0:0 -it splunk bash
```
and modify `/opt/splunk/etc/system/local/server.conf` file and append:
```
[kvstore]
serverCert = /opt/splunk/certs/combined.pem
sslVerifyServerCert = True
sslVerifyServerName = True
```

and restart splunk:
```
/opt/splunk/bin/splunk restart splunkd
```

# create ssh tunnel to ssh instance splunk1.example.com
```
ssh ec2-user@splunk1.example.com -R 4000:127.0.0.1:8088 -i ~/.ssh/insights-qa.pem
```

# Setup venv, create indexes, build and install
```
podman exec --user 0:0 -it splunk /opt/work/container_scripts/setup_splunk_container.sh
podman exec --user 0:0 -it splunk /opt/work/container_scripts/create_indexes_container.sh # type admin when asked what username to use
podman exec --user 0:0 -it splunk /opt/work/container_scripts/make_release_container.sh # type admin when asked what username to use
```

# Integrate splunk app with c.r.c
- when adding the app, as a hostname add https://splunk1.example.com:4000
