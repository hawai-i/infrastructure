#!/bin/bash

# This scripts expects 2 environment variables:
# - EMAIL: the email adress used to log into letsencrypt
# - DOMAINS: All Domains for which a certificate should be acquired separated 
#            by comma without space
# 
# This script first creates a self signed dummy certificate, so
# that the nginx, who relies on this certificate file, can start.
# After that, this script waits, until the Domain for which a certificate
# should be acquired is reachable.
# Then certbot is called to create the certificates. Afterwards, every 12h certbot renew
# is called, so that the certificates are updated if necessary.


# get the first domain only for the dummy certificate
DOMAIN=$(echo $DOMAINS | cut -d"," -f1)
if [ -z "$DOMAIN" ]
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
until curl --silent -I http://$DOMAIN/.well-known/acme-challenge/
do
	echo "waiting for http://$DOMAIN/.well-known/acme-challenge/ to be accessible from outside..."
	sleep 5
done


# run certbot
certbot certonly --noninteractive --webroot --agree-tos --expand --email $EMAIL -w /var/www/acme-challenge -d ${DOMAINS//,/ -d } && \
cp -rL /etc/letsencrypt/live/* /etc/certs/ && \
while [ true ] ; \
do certbot renew --noninteractive; cp -rL /etc/letsencrypt/live/* /etc/certs/; sleep 12h; \
done;
