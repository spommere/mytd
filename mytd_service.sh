#!/bin/bash
  
dir=`dirname $0`
TASKS_DIR=$dir/tasks
. $dir/env

if [[ $# -ne 1 ]]
then
  echo abort
  exit 1
fi

mytdpid=$1
krc=0
echo "`/bin/date` Starting $0 (pid $$)" >> $TASKS_DIR/.mytd_service.log

while [[ $krc -eq 0 ]]
do
  sleep 10
  kill -0 $mytdpid
  krc=$?

  # check inbox
  for req in `ls $TASKS_DIR/inbox`
  do
    echo "`/bin/date` Found the following request: $req" >> $TASKS_DIR/.mytd_service.log
    cmd=`cat $TASKS_DIR/inbox/$req`
    $dir/mytd.sh<<EOF
$cmd
e
EOF
    echo "`/bin/date` $req $cmd" >> $TASKS_DIR/.mytd_service.log
    rm -f $TASKS_DIR/inbox/$req
    sleep 1
  done
done
echo "`/bin/date` Exiting $0 (pid $$)" >> $TASKS_DIR/.mytd_service.log
exit 0
