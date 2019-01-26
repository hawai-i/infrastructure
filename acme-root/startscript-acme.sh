#!/bin/bash

DOMAIN=nginx.rohrstetten.jmj-works.com
EMAIL=martin-jan@arcor.de

# This script runs the acme client

# first, create a dummy certificate for nginx to start
mkdir -p /etc/certs/$DOMAIN
openssl req -x509 -newkey rsa:4096 \
        -keyout /etc/certs/$DOMAIN/privkey.pem \
        -out /etc/certs/$DOMAIN/fullchain.pem \
        -nodes -subj "/C=DE/ST=Bavaria/L=Munich/O=jmj-works.com/OU=nextcloud self signing/CN=$DOMAIN"

# wait until nginx is started properly
sleep 65s 

# run certbot
certbot certonly --noninteractive --webroot --agree-tos --expand --email $EMAIL -w /var/www/acme-challenge -d $DOMAIN -d office.rohrstetten.jmj-works.com && \
cp -rL /etc/letsencrypt/live/* /etc/certs/ && \
while [ true ] ; \
do certbot renew --noninteractive; cp -rL /etc/letsencrypt/live/* /etc/certs/; sleep 12h; \
done;
