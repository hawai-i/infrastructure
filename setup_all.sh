#! /bin/bash

MYSQL_PASSWORD=$(< /dev/urandom tr -dc _A-Za-z0-9 | head -c${1:-32};echo;)
MYSQL_ROOT_PASSWORD=$(< /dev/urandom tr -dc _A-Za-z0-9 | head -c${1:-32};echo;)
NEXTCLOUD_ADMIN_PASSWORD=$(< /dev/urandom tr -dc _A-Za-z0-9 | head -c${1:-32};echo;)


##########
# MySQL
echo "Starting MariaDB..."
docker run -d --name nextcloud-db --hostname=mariadb \
           -v nextcloud-db-vol:/var/lib/mysql \
           -v $PWD/mariaDB/config:/etc/mysql/conf.d \
           -e MYSQL_ROOT_PASSWORD=$MYSQL_ROOT_PASSWORD \
           -e MYSQL_PASSWORD=$MYSQL_PASSWORD \
           -e MYSQL_USER=nextcloud \
           -e MYSQL_DATABASE=nextcloud \
--restart=always mariadb:10.3

echo "Done. Waiting..."
sleep 30

##########
# Elasticsearch (Fulltext search)
docker run -d --name elasticsearch \
           -v elasticdata:/usr/share/elasticsearch/data \
           -e bootstrap.memory_lock=true \
           -e "discovery.type=single-node" \
           -e "ES_JAVA_OPTS=-Xms512m -Xmx512m" \
docker.elastic.co/elasticsearch/elasticsearch:6.4.0

docker exec -it elasticsearch bin/elasticsearch-plugin install --batch ingest-attachment

echo "Starting nextcloud..."
docker run -d --hostname=nextcloud --name nextcloud \
           -v nextcloud-data:/var/www/html \
           -e MYSQL_DATABASE=nextcloud \
           -e MYSQL_USER=nextcloud \
           -e MYSQL_PASSWORD=$MYSQL_PASSWORD \
           -e MYSQL_HOST=database:3306 \
           -e NEXTCLOUD_ADMIN_USER=admin \
           -e NEXTCLOUD_ADMIN_PASSWORD=$NEXTCLOUD_ADMIN_PASSWORD \
           --link nextcloud-db:database \
           --link elasticsearch:elasticsearch \
--restart=always nextcloud



echo "Done. Waiting..."
# wait until initial setup is done
sleep 5

###########
# https://docs.nextcloud.com/server/9/admin_manual/configuration_server/reverse_proxy_configuration.html
# "overwritewebroot"  => "/nextcloud",
# su www-data -s $(which bash) -c "php occ config:system:set overwritewebroot --value=\"/nextcloud\""
# su www-root -c php occ config:system:set overwritewebroot --value="/nextcloud"
# chsh -s /bin/bash www-data
###########
###########
# make sure everything is owned by www-data
docker exec -it nextcloud /bin/bash -c 'chown -R www-data /var/www/html'
# install nextcloud
echo "Installing nextcloud..."
docker exec -it nextcloud /bin/bash -c 'su www-data -s $(which bash) -c "php occ maintenance:install --no-interaction --admin-pass=\"$NEXTCLOUD_ADMIN_PASSWORD\" --database=\"mysql\" --database-host=\"database:3306\" --database-name=\"nextcloud\"  --database-user=\"nextcloud\" --database-pass=\"$MYSQL_PASSWORD\" --admin-user=\"admin\""'
# configure sub-uri / proxy
docker exec -it nextcloud /bin/bash -c 'su www-data -s $(which bash) -c "php occ config:system:set overwritewebroot --value=\"/nextcloud\""'
docker exec -it nextcloud /bin/bash -c 'su www-data -s $(which bash) -c "php occ config:system:set overwriteprotocoll --value=\"https\""'
docker exec -it nextcloud /bin/bash -c 'su www-data -s $(which bash) -c "php occ config:system:set overwriteprotocoll --value=\"https\""'
docker exec -it nextcloud /bin/bash -c 'su www-data -s $(which bash) -c "php occ config:system:set trusted_domains 0 --value=nginx.rohrstetten.jmj-works.com"'

#php occ config:system:set trusted_domains 2 --value=##__DOMAIN2__## \

# Login is very slow --> bruteforce protection slows that down
docker exec -it nextcloud /bin/bash -c 'su www-data -s $(which bash) -c "php occ config:system:set auth.bruteforce.protection.enabled --value=\"false\" --type=boolean"'

##########
# grant access to local folder: 
# * make the group owncloud (gid=1000) the owner of your folder: chown -R :owncloud /folder
# * to make sure, that new folders are also readable by the group, set the SGID bit: chmod -R g+s /folder
# * finally: in the docker image create a corresponding group and add www-data to the group
docker exec -it nextcloud /bin/bash -c 'groupadd -g 1000 owncloud'
docker exec -it nextcloud /bin/bash -c 'usermod -a -G owncloud www-data'
echo "Done..."

sleep 10

###############
# starting collabora
docker run -d --name nextcloud-collabora -e "domain=nginx\.rohrstetten\.jmj-works\.com" --restart always --cap-add MKNOD collabora/code

###############
# Certbot
echo "Starting certbot..."
mkdir acme-challenge
mkdir certs
docker run -d --name certbot-daemon \
           -v $PWD/acme-root:/root \
           -v $PWD/acme-challenge:/var/www/acme-challenge \
           -v $PWD/certs:/etc/certs \
           --entrypoint="/bin/sh" \
--restart=always certbot/certbot:latest /root/startscript-acme.sh
echo "Done. Waiting..."

# wait until initial temporary certs are created
sleep 60

################
# nginx frontend
echo "Starting nginx frontend..."
docker run -d --name frontend-nginx \
           -v $PWD/nginx-root:/root \
           -v $PWD/acme-challenge:/etc/nginx/ssl/acme-challenge/ \
           -v $PWD/certs:/etc/nginx/ssl/certs/ \
           -v $PWD/nginx-conf:/etc/nginx/conf.d/ \
           -p 30080:80 \
           -p 30443:443 \
           --link nextcloud:nextcloud-local \
           --link nextcloud-collabora:collabora \
           --entrypoint="/bin/sh" \
--restart=always nginx:latest /root/startscript-nginx.sh
echo "Done. Waiting..."

echo "Nextcloud admin password: $NEXTCLOUD_ADMIN_PASSWORD"

#####################
# Afterwards configuring using the web interface:
# 
# * change admin password
# * activate/install apps: LDAP User Group Backend, External Storage Support, Talk (Social & Communication), collabora (office)
# * settings
#   * External storages: 
#       - Folder name: Blackbox
#       - External Storage: local
#       - Authentication: none
#       - Configuration: /data
#   * LDAP/AD integration
#       - Hostname: IP of connecting virtual switch (10.0.3.1)
#       - Port: 389
#       - UserDN: cn=admin,dc=ldap,dc=blackbox,dc=ingolstadt
#       - Password: *** (LDAP Passwort set in QNAP under LDAP)
#       - BaseDN: ou=people,dc=ldap,dc=blackbox,dc=ingolstadt
#       - Tab Login attributes: Checkmark Username and Email Address, Other Attributes: cn
#   * collabora online
#       - set collabora online server to: https://office.dev.jmj-works.com

#       start elastic
#       docker run -d --name elasticsearch            -v elasticdata:/usr/share/elasticsearch/data            -e bootstrap.memory_lock=true            -e "discovery.type=single-node"            -e "ES_JAVA_OPTS=-Xms2g -Xmx2g" elasticsearch_nextcloudindexer
#       start indexing:
#       su www-data -s $(which bash) -c "php -d memory_limit=1G occ fulltextsearch:index"



