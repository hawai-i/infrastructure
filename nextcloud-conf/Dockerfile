FROM nextcloud:15.0
RUN apt-get update && apt-get install -y smbclient
COPY smb.conf /etc/samba/smb.conf
COPY apcu.config.php /usr/src/nextcloud/config


