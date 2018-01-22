####################################################################
#
#           create group replication "cluster"
#           
#       21.1.2018 barucho@gmail.com - created  
#
######################################################################



## clean data 
rm -rf /u01/data/mysql_group1/
###


### create data dir
mkdir -p /u01/data/mysql_group1/{1,2,3,4}

## fix per...
chown -R mysql.mysql /u01/data/mysql_group1/


## create 3 instanses 
mysqld --initialize-insecure  --datadir=/u01/data/mysql_group1/1
mysqld --initialize-insecure  --datadir=/u01/data/mysql_group1/2
mysqld --initialize-insecure  --datadir=/u01/data/mysql_group1/3



##mysql01 

mysqld --defaults-file=/u01/etc/mysql_group1/1/my.cnf &

mysql -u root  --port 24801 --protocol=tcp


INSTALL PLUGIN group_replication SONAME 'group_replication.so';

####create replication user 

SET SQL_LOG_BIN=0;
CREATE USER rpl_user@'%';
GRANT REPLICATION SLAVE ON *.* TO rpl_user@'%' IDENTIFIED BY 'rpl_pass';
FLUSH PRIVILEGES;
SET SQL_LOG_BIN=1;
CHANGE MASTER TO MASTER_USER='rpl_user', MASTER_PASSWORD='rpl_pass' FOR CHANNEL 'group_replication_recovery';

##
#To start the group, the only thing left to do is to instruct server s1 to bootstrap the group and then start group replication. Mind you that bootstrap should only be done by a single server, the one that starts the group and only once. Note also the value of the bootstrap configuration option was not persisted in the configuration file. Had it been persisted, the server could crash and restart and automatically bootstrap a second group with the same name. This would result in two distinct groups with the same name. The same reasoning applies to stopping and restarting the plugin with this option set to ON.
###
SET GLOBAL group_replication_bootstrap_group=ON;
START GROUP_REPLICATION;
SET GLOBAL group_replication_bootstrap_group=OFF;


SELECT * FROM performance_schema.replication_group_members;

 
 CREATE DATABASE test;
 use test;
 

 CREATE TABLE test.t1 (
  `id` mediumint(9) NOT NULL AUTO_INCREMENT,
  `name` varchar(255) NOT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB ;




INSERT INTO test.t1(name) VALUES ('My'),('Max'),('Maira');

select *  FROM test.t1;





##################
#    mysql02
#
################

##Adding a Second Server



mysqld --defaults-file=/u01/etc/mysql_group1/2/my.cnf &

##connect 
mysql -u root --port 24802 --protocol=tcp

## install plugin
INSTALL PLUGIN group_replication SONAME 'group_replication.so';


## create rep user 
SET SQL_LOG_BIN=0;
CREATE USER rpl_user@'%';
GRANT REPLICATION SLAVE ON *.* TO rpl_user@'%' IDENTIFIED BY 'rpl_pass';
FLUSH PRIVILEGES;
SET SQL_LOG_BIN=1;
CHANGE MASTER TO MASTER_USER='rpl_user', MASTER_PASSWORD='rpl_pass' FOR CHANNEL 'group_replication_recovery';



# start group_replication
START GROUP_REPLICATION;

# TEST 
SELECT * FROM performance_schema.replication_group_members;


INSERT INTO test.t1(name) VALUES ('MongoDB'),('ElK'),('Postgrsql');
select *  FROM test.t1;



##################
#    mysql03
#
################
mysqld --defaults-file=/u01/etc/mysql_group1/3/my.cnf &

mysql -u root  --port 24803 --protocol=tcp



# install plugin
 INSTALL PLUGIN group_replication SONAME 'group_replication.so';
 #
SET SQL_LOG_BIN=0;
CREATE USER rpl_user@'%';
GRANT REPLICATION SLAVE ON *.* TO rpl_user@'%' IDENTIFIED BY 'rpl_pass';
FLUSH PRIVILEGES;
SET SQL_LOG_BIN=1;
CHANGE MASTER TO MASTER_USER='rpl_user', MASTER_PASSWORD='rpl_pass' FOR CHANNEL 'group_replication_recovery';


 # start group_replication
START GROUP_REPLICATION;


##TEST
 
SELECT * FROM performance_schema.replication_group_members;

INSERT INTO test.t1(name) VALUES ('Ms-SQL'),('BD2'),('Oracle');

select *  FROM test.t1;


################
### kill 3 #####
###############
kill $(ps -ef |grep mysql_group1/3 |grep -v grep |awk '{print $2}')
## connect to mysql01 and insert 
INSERT INTO test.t1 VALUES (10, 'prometheus');
## start 3 
mysqld --defaults-file=/u01/etc/mysql_group1/3/my.cnf &

mysql -u root  --port 24803 --protocol=tcp

START GROUP_REPLICATION;

## test from mysql03
select *  FROM test.t1;







## monitor 
#http://mysqlhighavailability.com/mysqlha/gr/doc/monitoring.html

performance_schema.replication_group_member_stats




select * from performance_schema.replication_group_member_stats\G
select * from performance_schema.replication_applier_status\G
select * from performance_schema.replication_group_members\G


select * from performance_schema.replication_connection_status\G







