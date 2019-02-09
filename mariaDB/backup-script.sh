#!/bin/bashUnd 
while true; do 
	mysqldump -h database -u nextcloud --password=$MYSQL_PASSWORD --single-transaction nextcloud > backup.sql 
        tar czf /backups/mysql_$(date '+%Y-%m-%d-%H-%M-%S').tar.gz backup.sql
        rm backup.sql 
        tar czf /backups/html_$(date '+%Y-%m-%d-%H-%M-%S').tar.gz /var/www/html
        find /backups/ -type f -name '*.tar.gz' -mtime +1 -exec rm {} \;
        sleep 12h 
done
