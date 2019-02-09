#!/bin/bash

# All Domains separated by comma without space
DOMAINS=nginx.blackbox.jmj-works.com,office.dev.jmj-works.com,farb.works
EMAIL=martin-jan@arcor.de

# This script runs the acme client

# get the first domain only for the dummy certificate
DOMAIN=$(echo $DOMAINS | cut -d"," -f1)
if [ -z "$var" ]
then
	# assuming it is empty, because there is only 1 domain in DOMAINS and cut fails in busybox
	DOMAIN=$DOMAINS
fi


# first, create a dummy certificate for nginx to start
mkdir -p /etc/certs/$DOMAIN
openssl req -x509 -newkey rsa:4096 \
        -keyout /etc/certs/$DOMAIN/privkey.pem \
        -out /etc/certs/$DOMAIN/fullchain.pem \
        -nodes -subj "/C=DE/ST=Bavaria/L=Munich/O=x42x64/OU=letsencrypt self signing/CN=$DOMAIN"

# wait until nginx is started properly
sleep 65s 


# run certbot
#certbot certonly --noninteractive --webroot --agree-tos --expand --email $EMAIL -w /var/www/acme-challenge -d $DOMAIN -d office.dev.jmj-works.com -d farb.works && \
# ${DOMAINS//,/ -d } replaces all ',' within DOMAINS by ' -d '
certbot certonly --noninteractive --webroot --agree-tos --expand --email $EMAIL -w /var/www/acme-challenge -d ${DOMAINS//,/ -d } && \
cp -rL /etc/letsencrypt/live/* /etc/certs/ && \
while [ true ] ; \
do certbot renew --noninteractive; cp -rL /etc/letsencrypt/live/* /etc/certs/; sleep 12h; \
done;
