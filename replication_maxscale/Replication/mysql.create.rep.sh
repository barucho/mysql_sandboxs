#! /bin/bash
################################################
# Name: MySQLRep.sh
#
# Description:
# manage mysql replication
#
#
# History:
#
# 15.8.2017 -
# baruch@brillix.co.il created
# TODO
# chack if db have binlog Configuration
###################################################
#DEBUG
#set -x


if [[ $# -eq 0 ]]; then
  # unknown option
  echo -e "use: -m=<master> -s=<slave> -e=[status|create|failover|swichover|ssh] -u<username>"
  echo -e "use: Create Replication: -m=<master> -s=<slave> -p=<mysql_root_password> -e=create"
  echo -e "use: test Replication: -m=<master> -s=<slave> -p=<mysql_root_password> -e=test"
  echo -e "use: Enable ssh: -u=<username> -e=ssh"
  exit 1
fi
##### get input from prompt
for i in "$@"
do
case $i in
    -s=*|--slave=*)
    SLAVE="${i#*=}"
    shift # past argument=value
    ;;
    -m=*|--master=*)
    MASTER="${i#*=}"
    shift # past argument=value
    ;;
    -e=*|--execute=*)
    EXECUTE="${i#*=}"
    shift # past argument=value
    ;;
    -u=*|--username=*)
    USERNAME="${i#*=}"
    shift # past argument=value
    ;;
     -p=*|--rootpassword=*)
    MYSQL_PASSWORD="${i#*=}"
    shift # past argument=value
    ;;
    *)
exit 1
    ;;
esac
done
echo "master: "$MASTER "slave: "$SLAVE
echo "execute:"$EXECUTE




TestSlave()
{
  sql="show slave status\G"
  res=$(ssh $SLAVE "mysql -u root -p$MYSQL_PASSWORD -e \"$sql\"" |awk '/Slave_IO_Running/ {print $2}')
  if [ $res = "Yes" ]; then
    echo -e " '\e[32m OK SLAVE Slave_IO_Running is UP \e[0m'"
  else
    echo -e " '\e[31m ERROR SLAVE Slave_IO_Running is DOWN \e[0m'"
  fi
  res=$(ssh $SLAVE "mysql -u root -p$MYSQL_PASSWORD -e \"$sql\"" |awk '/Slave_SQL_Running:/ {print $2}')
  if [ $res = "Yes" ]; then
    echo -e "'\e[32m OK SLAVE Slave_SQL_Running is UP \e[0m'"
  else
    echo -e " '\e[31m ERROR SLAVE Slave_SQL_Running is DOWN \e[0m'"
  fi
  sql="show slave status\G"
  res=$(ssh $SLAVE "mysql -u root -p$MYSQL_PASSWORD -e \"$sql\"" |awk '/Last_Errno/ {print $2}')
  if [ $res !=  0 ]; then
    echo -e "\e[31m ERROR slave error: \e[0m" $res
  fi
  sql="show slave status\G"
  res=$(ssh $SLAVE "mysql -u root -p$MYSQL_PASSWORD -e \"$sql\"" |awk '/Seconds_Behind_Master/ {print $2}')
  echo "Test Seconds_Behind_Master: " $res
  sql="select @@server_uuid Master_UUID\G"
  res=$(ssh $MASTER "mysql -u root -p$MYSQL_PASSWORD -e \"$sql\""|awk '/Master_UUID/')
  echo "master uuid: " $res
  sql="show slave hosts\G"
  res=$(ssh $MASTER "mysql -u root -p$MYSQL_PASSWORD -e \"$sql\""|awk '/Slave_UUID/')
  echo  $res
}


CreateSlave(){

#
# Configuration
###########
  BACKUP_DIR="tmpbackup"
  BACKUP_BASE_DIR="/log/backup/"
  BACKUP_FULL_PATH="$BACKUP_BASE_DIR/$BACKUP_DIR"
  TAR_DIR="/tmp/"
  MYSQL_USER="root"
  MYSQL=/usr/bin/mysql
  MYSQLBACKUP=/usr/bin/innobackupex
  MYSQL_MY_CNF=/etc/mysql/my.cnf
  MASTER_PORT=3306
  MASTER_SSH_PORT=22
  MASTER_SOCKET=/var/run/mysqld/mysqld.sock
  MASTER_IP=$MASTER
  SLAVE_IP=$SLAVE
  SSH_USER="mysql"
  ##############################


  echo -e " '\e[31m YOU GOING TO DELETE ALL DATA FROM $SLAVE \e[0m'"
  read -p "Are you sure? " -n 1 -r
  echo    # (optional) move to a new line
  if [[ $REPLY =~ ^[Nn]$ ]]
  then
    exit 1
  fi


  ###########
  # create user for replication
  ###########
 # echo "Create REP USERS"
 # TODO
 #CREATE USER 'repuser'@'%';
#GRANT REPLICATION SLAVE ON *.* TO 'repuser'@'%' IDENTIFIED BY 'oracle';
#GRANT REPLICATION CLIENT ON *.* TO 'repuser'@'%';
  #sql="grant replication slave,REPLICATION CLIENT on *.* to 'repuser'@'%' identified by 'oracle' REQUIRE SSL"
  #res=$(ssh $MASTER "mysql -u root -p$MYSQL_PASSWORD -e \"$sql\"")
  #sql="grant replication client, replication slave, SUPER, PROCESS, RELOAD on *.* to 'repuser'@'localhost' identified by 'oracle' REQUIRE SSL"
 # res=$(ssh $MASTER "mysql -u root -p$MYSQL_PASSWORD -e \"$sql\"")
  #test if backupdir exist
  echo "clean backup dir"
  #clean backupdir
  rm -rf $BACKUP_FULL_PATH
  #create backupdir
  mkdir -p $BACKUP_FULL_PATH
  echo "create backup"
  #start with full backup of master databse
  $MYSQLBACKUP --socket=$MASTER_SOCKET --no-timestamp --user=$MYSQL_USER --password=$MYSQL_PASSWORD $BACKUP_FULL_PATH &>/dev/null
  $MYSQLBACKUP --apply-log $BACKUP_FULL_PATH &>/dev/null
  # get backup information
  MASTER_LOG_FILE=`awk '{print $1}' \$BACKUP_BASE_DIR/\$BACKUP_DIR/xtrabackup_binlog_info`
  MASTER_LOG_POS=`awk '{print $2}' \$BACKUP_BASE_DIR/\$BACKUP_DIR/xtrabackup_binlog_info`

  # create tar file
  cd $BACKUP_BASE_DIR
  #clean old tar
  \rm -rf $BACKUP_DIR.taz
  #create tar  
  echo "create tar"
  tar  cfz $BACKUP_DIR.taz  $BACKUP_DIR
  #claen backupdir
  echo "clean backup dir"
  \rm -rf $BACKUP_DIR
  ############################
  #this part will run on slave machine
  #
  ############################
  # first test connection to slave server
  status=`ssh $SLAVE_IP 'exit';echo $?`
  echo "testing connecion to $SLAVE_IP"
  if [ $status -ne 0  ]; then
    echo "\e[31m error connecting to $SLAVE_IP \e[0m"
    exit 1
  else
    echo -e '\e[32m OK \e[0m'
  fi

  echo "create backup dir on slave"
  status=`ssh $SLAVE_IP "mkdir -p $BACKUP_BASE_DIR"`
  echo "copy backup to slave machine"
  #copy tar file to slave machine
  status=`scp $BACKUP_BASE_DIR/$BACKUP_DIR.taz $SLAVE_IP:$BACKUP_BASE_DIR/ ;echo $?`
  if [ $status -ne 0  ]; then
    echo "\e[31m error copy to $SLAVE_IP \e[0m"
    exit 1
  else
    echo -e '\e[32m OK \e[0m'
  fi
  # open tar on slave
  echo "open tar on slave"
  status=`ssh $SLAVE_IP "cd \$BACKUP_BASE_DIR ; tar xfz \$BACKUP_DIR.taz"`
  echo "clean slave tar"
  status=`ssh $SLAVE_IP "cd \$BACKUP_BASE_DIR ; \\rm -rf \$BACKUP_DIR.taz"`
  #####
  #start recover slave
  #######
  #clean slave datadir
  #first get datadir location
  SLAVE_DATA_DIR=`ssh \$SLAVE_IP "awk '/datadir/ {print \\$3}' \$MYSQL_MY_CNF"`
  SLAVE_BIN_LOG_FILE=`ssh \$SLAVE_IP "awk '/log-bin/ {print \\$3}' \$MYSQL_MY_CNF"`
  SLAVE_RELAY_LOG_FILE=`ssh \$SLAVE_IP "awk '/^relay_log/ {print \\$3}' \$MYSQL_MY_CNF"`
  #stop slave server
  echo "stop slave MySQL server"
  ssh $SLAVE_IP "mysqladmin -u root -p$MYSQL_PASSWORD shutdown"
#
  status=`ssh $SLAVE_IP 'pgrep mysqld_safe |wc -l'`
# test if slave is down
  if [ $status -ne 0  ]; then
    echo -e "\e[31m error stoping MySQL SLAVE \e[0m"
    # test if slave is down
    status=`ssh $SLAVE_IP 'pgrep mysql_safe |wc -l'`
    if [ $status -ne 0  ]; then
      echo -e "\e[31m error stoping MySQL SLAVE \e[0m"
      exit 1
    else
      echo -e '\e[32m OK SLAVE MySQL is DOWN \e[0m'
    fi
  else
    echo -e '\e[32m OK SLAVE MySQL is DOWN \e[0m'

  fi
  #clean datadir on slave
  ##TODO TOFIX to dynamic !!###
  ssh $SLAVE_IP "\\rm -rf /u01/data/mysql"
  ssh $SLAVE_IP "\\rm -rf /u01/log/relay-bin.*"
  ssh $SLAVE_IP "\\rm -rf /u01/log/mysql-bin.*"
  
  #TODO :clean old logs

  #SERVER_ID = `echo $SLAVE_IP | sed 's/[^1-9]//g'`
  #echo "New server ID:" $SERVER_ID
  #fix server_id in my.cnf on slave
  #remove server_id variable
  #status=`ssh $SLAVE_IP "cp \$MYSQL_MY_CNF \$MYSQL_MY_CNF.installorig"`
  #status=`ssh $SLAVE_IP "sed -i  \"/server_id/d\" \$MYSQL_MY_CNF"`
  #status=`ssh $SLAVE_IP "sed -i  \"/\\[mysqld\\]/a server_id = \$SERVER_ID\" \$MYSQL_MY_CNF"`
  
  #recover backup to slave
  echo "recover backup on remote server"
  status=`ssh $SLAVE_IP "\$MYSQLBACKUP --copy-back \$BACKUP_BASE_DIR/\$BACKUP_DIR &>/dev/null"`
  status=`ssh $SLAVE_IP "chown -R mysql.mysql \$SLAVE_DATA_DIR"`
  
  #start slave
  echo "starting slave MySQL server"
  nohup ssh -f $SLAVE_IP "nohup /usr/bin/mysqld_safe  /dev/null 2>&1 & "  
  sleep 10
  # kill the ssh
  #kill %-1
  status=`ssh $SLAVE_IP 'pgrep mysql |wc -l'`
  if [ $status -ne 0  ]; then
  echo -e '\e[32m OK SLAVE MySQL is UP \e[0m'
  else
    echo "\e[31m error starting MySQL SLAVE look at slave logs\e[0m"
    exit 1
  fi
   echo "resert mysql status"
  sql="stop slave;reset slave all;reset master;"
  status=`ssh $SLAVE_IP "mysql -u root -p$MYSQL_PASSWORD -e \"\$sql\""`
  echo "slave Configuration "
  #sql="change master to MASTER_PORT=3306,MASTER_HOST='$MASTER_IP',MASTER_USER='repuser',MASTER_PASSWORD='oracle',MASTER_AUTO_POSITION=1"
  sql="change master to MASTER_PORT=3306,MASTER_HOST='$MASTER_IP',MASTER_USER='repuser',MASTER_PASSWORD='oracle',MASTER_LOG_FILE='$MASTER_LOG_FILE',MASTER_LOG_POS=$MASTER_LOG_POS"
  status=`ssh $SLAVE_IP "mysql -u root -p$MYSQL_PASSWORD -e \"\$sql\""`
  sql="start slave"
  status=`ssh $SLAVE_IP "mysql -u root -p$MYSQL_PASSWORD -e \"\$sql\""`

}



# enable ssh with no password on remote host
#get hostname and username
EnableSSH(){
  username=$USERNAME
  #clean
  \rm -r ~/.ssh/id_rsa*
  \rm -r ~/.ssh/known_hosts
  #regen key #!!!do NOT REMOVE EMPTY LINEs after the EOL!!
/usr/bin/ssh-keygen << EOL



EOL
  ######
  #copy cert file
  /usr/bin/ssh-copy-id $username@mysql02-priv
  /usr/bin/ssh-copy-id $username@mysql01-priv
  /usr/bin/ssh-copy-id $username@mysql03-priv
}





FailOver(){

# first test if replication is runnnig
#Test Seconds_Behind_Master
sql="show slave status\G"
res=$(ssh $SLAVE "mysql -u root -e \"$sql\"" |awk '/Seconds_Behind_Master/ {print $2}')
echo "Test Seconds_Behind_Master" $a
######
sql="show slave status\G"
res=$(ssh $SLAVE "mysql -u root -e \"$sql\"" |awk '/Slave_IO_Running/ {print $2}')
if [ $res != "Yes" ]; then
  echo "ERROR slave not running"
fi
res=$(ssh $SLAVE "mysql -u root -e \"$sql\"" |awk '/Slave_SQL_Running:/ {print $2}')
if [ $res != "Yes" ]; then
  echo "ERROR slave not running"
fi
sql="show slave status\G"
res=$(ssh $SLAVE "mysql -u root -e \"$sql\"" |awk '/Last_Errno/ {print $2}')
if [ $res !=  0 ]; then
  echo "ERROR slave error: " $res
fi
######

#stop slave
sql="stop slave\G"
a=$(ssh $SLAVE "mysql -u root -e \"$sql\"" |awk '/Seconds_Behind_Master/ {print $2}')

  sql="show slave status\G"
  res=$(ssh $SLAVE "mysql -u root -e \"$sql\"" |awk '/Slave_IO_Running/ {print $2}')
  if [ $res != "No" ]; then
    echo "ERROR stoping replication"
    exit 1
  fi
  res=$(ssh $SLAVE "mysql -u root -e \"$sql\"" |awk '/Slave_SQL_Running/ {print $2}')
  if [ $res != "No" ]; then
    echo "ERROR stoping replication"
    exit 1
  fi
  #cleanup
  sql="RESET SLAVE;"
  res=$(ssh $SLAVE "mysql -u root -e \"$sql\"")
  sql="RESET MASTER;"
  res=$(ssh $SLAVE "mysql -u root -e \"$sql\"")
}


RecreateSSL()
{
  echo "recreate ssl"
#mysql_ssl_rsa_setup
}



SwitchOver()
{
## first stop slave
FailOver
### set the master as slave
sql="change master to MASTER_PORT=3306,MASTER_HOST='$SLAVE',MASTER_USER='repuser',MASTER_PASSWORD='RepUserPaW0rdS2016',MASTER_AUTO_POSITION = 1"
res=$(ssh $MASTER "mysql -u root -e \"$sql\"")
sql="start slave\G"
res=$(ssh $MASTER "mysql -u root -e \"$sql\"")
}

########MAIN##############
case $EXECUTE in
  test)
  TestSlave
      ;;
  create)
  CreateSlave
  TestSlave
  ;;
  ssh)
  EnableSSH
  ;;
  failover)
  FailOver
  ;;
  swichover)
  SwitchOver
  ;;
*)
  echo "ERROR no EXECUTE use -e=[status|create|failover|swichover|ssh]"
exit 1
esac
