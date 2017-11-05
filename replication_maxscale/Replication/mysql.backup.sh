#! /bin/bash -x
#****************************************************************************
# Name: mysql.backup.sh
#
# Description:
#  backup MySQl by running innobackupex
# History:
#
# 15.8.2017 -
# baruch@brillix.co.il created
# 
# Usage:
#   mysql.backup.sh
#
# Dependencies:
#   mysql 5.6 +
#  backup user need to be created
#  GRANT LOCK TABLES, SELECT ON *.* TO 'backupuser'@'%' IDENTIFIED BY 'password';
#  GRANT FILE ON *.* TO 'backupuser'@'%';
#  GRANT REPLICATION CLIENT ON *.* to 'backupuser'@'%';
#  GRANT RELOAD  ON *.* to 'backupuser'@'%';
#****************************************************************************
TIMESTAMP=$(date +%F"-"%H%M)
# Configuration
BACKUP_DIR_BASE="/backup/full/"
BACKUP_DIR="$BACKUP_DIR_BASE/$TIMESTAMP"
MYSQL_USER="root"
MYSQL=/usr/bin/mysql
MYSQL_PASSWORD="Ght3doal#"
RETENTION=30
DATE=`date`
MAIL_TO="alerts@camilyo.com"
#
innobackupex  --user=$MYSQL_USER --password=$MYSQL_PASSWORD $BACKUP_DIR && INNOBACKUP_STATUS="OK"|| INNOBACKUP_STATUS="ERROR"  
#gzip
tar --remove-files -zcvf  $BACKUP_DIR.tar $BACKUP_DIR && TAR_STATUS="OK"|| TAR_STATUS="ERROR"  
#clean
(find $BACKUP_DIR_BASE/* -mtime +$RETENTION -exec rm {} \; )&& CLEAN_STATUS="OK"|| CLEAN_STATUS="ERROR"  
##report 
##send mail### clean

/usr/sbin/ssmtp $MAIL_TO  << EOFMAIL
To: $MAIL_TO
From: no-reply@camilyo.com
Subject: info backup run on `hostname`

local time :$DATE
"INNOBACKUP_STATUS:" ${INNOBACKUP_STATUS}
"TAR STATUS:" ${TAR_STATUS}
"CLEAN STATUS:" ${CLEAN_STATUS}

EOFMAIL