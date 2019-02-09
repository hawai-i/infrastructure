#!/bin/bah

cd /

mysql -h database -u nextcloud --password=$MYSQL_PASSWORD nextcloud < /restore/*.sql
tar -xzf /restore/html_*.tar.gz

