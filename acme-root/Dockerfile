FROM certbot/certbot:latest
RUN apk update && apk add --no-cache curl
ADD . /root
WORKDIR /root
ENTRYPOINT ["/bin/sh", "/root/startscript-acme.sh"]
