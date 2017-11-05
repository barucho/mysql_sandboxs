#! /bin/bash
# MySQL replication-failover  monitor for maxscale
#
#  29.8.2017 baruch@brillix.co.il - created 
#  5.9.2017 baruch@brillox.co.il - add maintenance to down server 
set -x
d=$(date)
for i in "$@"
do
	case $i in
	    initiator=*)
	    INITIATOR="${i#*=}"
	    shift # past argument=value
	    ;;
	    event=*)
	    EVENT="${i#*=}"
	    shift # past argument=value
	    ;;
	    live_nodes=*)
	    LIVE_NODES="${i#*=}"
	    shift # past argument=value
	    ;;
	    slave_list=*)
	    SLAVE_LIST="${i#*=}"
	    shift # past argument=value
	    ;;
	    *)
	exit 1
	    ;;
esac
done
###TODO fix connect  witout password
PASSWORD=mysql
###
SELECTED_SLAVE=$( echo $SLAVE_LIST | cut -d',' -f 1 )
SLAVE_HOST=$( echo $SELECTED_SLAVE | cut -d':' -f 1 )
SLAVE_PORT=$( echo $SELECTED_SLAVE | cut -d':' -f 2 )
_SERVER_DOWN=$(echo ${INITIATOR}|cut -d':' -f 1)
SERVER_DOWN=$(echo $_SERVER_DOWN | sed 's/\[//g' |sed 's/\]//g')
MASTER1=mps-prod-prtl-db1
MASTER2=mps-prod-prtl-db2
#MASTER3=mysql03

# looging event 
echo "[${d}] [from: ${INITIATOR}] - event: ${EVENT}" >> /var/log/maxscale/failover.log

# if event is server down run failover
if [ ${EVENT} = "master_down"  ];then
	echo "[${d}] [from: ${INITIATOR}] - event: ${EVENT}, Master is down, failover started" >> /var/log/maxscale/failover.log
	echo "serverdown : ${SERVER_DOWN}"  >> /var/log/maxscale/failover.log
		# select the new master 
		#TODO  test status of SERVER_DOWN --> if in maintenance DO NOTING 
		if [ ${SERVER_DOWN}=${MASTER1} ];then
			NEW_MASTER=${MASTER2}
			SERVER_TO_HIDE="mysql01"
		else
			NEW_MASTER=${MASTER1}
            SERVER_TO_HIDE="mysql02"
		fi
	echo "find new master: ${NEW_MASTER} disable server: ${SERVER_DOWN}"  >> /var/log/maxscale/failover.log
	#move to maintenance  SERVER_DOWN
	maxadmin -u admin -pmariadb -h ${MASTER1} set server ${SERVER_TO_HIDE} maintenance
	maxadmin -u admin -pmariadb -h ${MASTER2} set server ${SERVER_TO_HIDE} maintenance
	# change the  SERVER_DOWN to slave 
	sql="set global read_only=on;"
	echo $sql | mysql -u root -p${PASSWORD} -h ${SERVER_DOWN}

	#reset slave status on new master
	sql="stop slave;reset slave all;reset master;"
	echo $sql | mysql -u root -p${PASSWORD} -h ${NEW_MASTER}
	sql="set global read_only=off; "
	echo $sql | mysql -u root -p${PASSWORD} -h ${NEW_MASTER}

	echo "[${d}] [from: ${INITIATOR}] - event: ${EVENT}, Done failover" >> /var/log/maxscale/failover.log
fi
##send mail on event### 
#DATE=`date`
#MAIL_TO="baruch@brillix.co.il"
#ssmtp $MAIL_TO  << EOFMAIL
#To: $MAIL_TO
#From: no-reply@camilyo.com
#Subject: critical MySQl  EVENT from `hostname`

#local time :$DATE
#MySQL EVENT from `hostname`:
#${EVENT} 
#EOFMAIL
