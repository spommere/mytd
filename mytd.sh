#!/bin/bash

# Get the directory of the script
script_path=$(realpath "$0")
script_dir=$(dirname "$script_path")
cd $script_dir

mytdprog=`basename $0`
echo "Running $mytdprog pid $pid"

TASKS_DIR=${script_dir}/tasks
. ${script_dir}/env.sh

if [[ "$mytdprog" = "mytd_flask.sh" ]]
then
  set_formatting 0
fi

mkdir -p $TASKS_DIR/inbox
mytdpid=$$

# start mytd_service if requested
if [[ -n "$enable_mytd_service" ]] && [[ $enable_mytd_service -eq 1 ]]
then
  mytdssvcpid=`ps -ef|grep mytd_service.sh|grep -v grep|awk '{print $2}'`
  if [[ -z "$mytdsvcpid" ]]
  then
    ${script_dir}/mytd_service.sh $mytdpid 1>/dev/null 2>&1 &
  fi
fi

alltaskstati="11 30 80"
if [[ -z "$1" ]]
then
  project_name=Work
else
  project_name=$1
fi

PROJ_DIR=${script_dir}/tasks/$project_name

bye()
{
  echo kthxbye
  exit 0
}

currdatetime()
{
  currdt=$(/bin/date)
}

updateLastUpdate()
{
  local task_id=$1
  currdt=$(/bin/date +%Y-%m-%d_%H:%M:%S%Z)
  sed -i "s/^LastUpdate: .*/LastUpdate: $currdt/" $PROJ_DIR/$task_id.task
}
  
adddatetime()
{
  local task_id=$1
  currdatetime
  echo -e "\n$currdt" >> $PROJ_DIR/$task_id.task
}

taskexists()
{
  local task_id=$1
  trc=0
  if [[ ! -f $PROJ_DIR/$task_id.task ]]
  then
    echo "Task $task_id does not exist"
    trc=1
  fi
}
# Function to create a new project
create_project() {
    local project_name=$1
    mkdir -p $PROJ_DIR/
    echo "Project '$project_name' created."
    echo ""
}

# Function to create a new task
create_task() {
    local project_name=$1
    shift
    #local task_desc=`echo "$*"|cut -c1-50|sed "s/\//-/g"`
    local task_desc=`echo "$*"|cut -c1-50`
    local due_date=$(/bin/date -d "+0 days" +%Y-%m-%d)
    # task_id is Unix time
    local task_id=$(/bin/date +%s)
    local task_file=$PROJ_DIR/$task_id.task
    
    # Check if project exists, if not, create it
    if [ ! -d $PROJ_DIR/ ]; then
        create_project $project_name
    fi
    
    echo -e "Task: $task_desc\nDue: $due_date\nStatus: 11\nBug: \nLastUpdate: \n" > $task_file
    adddatetime $task_id
    echo "Task created" >> $task_file
    updateLastUpdate $task_id
    echo ""
}

# Function to delete an individual task
delete_task() {
    local project_name=$1
    local task_id=$2
    rm -f $PROJ_DIR/$task_id.task
    echo "Task '$task_id' deleted from project '$project_name'."
    echo ""
}

# Function to update a task status
update_task_status() {
    local project_name=$1
    local task_id=$2
    local new_status=$3
    local old_status=`grep ^Status $PROJ_DIR/$task_id.task|awk '{print $2}'`

    if [[ "$old_status" != "$new_status" ]]
    then
      sed -i "s/^Status: .*/Status: $new_status/" $PROJ_DIR/$task_id.task
      adddatetime $task_id
      echo -e "CHG: Status->${old_status}->${new_status} " >> $PROJ_DIR/$task_id.task
      updateLastUpdate $task_id
    else
      echo "Task status is already $new_status"
    fi
    echo ""
}

# Function to update the associated bug
update_bug() {
    local project_name=$1
    local task_id=$2
    local new_bug=$3
    local old_bug=`grep ^Bug: $PROJ_DIR/$task_id.task|awk '{print $2}'`

    if [[ "$old_bug" != "$new_bug" ]]
    then
      sed -i "s/^Bug: .*/Bug: $new_bug/" $PROJ_DIR/$task_id.task
      adddatetime $task_id
      echo -e "CHG: Bug->${old_bug}->${new_bug} " >> $PROJ_DIR/$task_id.task
      updateLastUpdate $task_id
    else
      echo "Bug is already $new_bug"
    fi
    echo ""
}

# Function to close one task and create a follow-up task
create_followup_task()
{
    local project_name=$1
    local task_id=$2
    if [[ -f $PROJ_DIR/$task_id.task ]]
    then
      old_task_desc=`grep ^Task: $PROJ_DIR/$task_id.task|awk '{print $2,$3,$4,$5,$6,$7,$8,$9,$10}'`

      # create a follow-up task
      create_task $project_name "Follow-up: $old_task_desc"
      new_task_id=`ls -1tr $PROJ_DIR/|tail -1|cut -f1 -d'.'`

      # update original task with relevant information
      adddatetime $task_id
      echo -e "Created a follow-up task $new_task_id $new_task_desc" >> $PROJ_DIR/$task_id.task

      # update the new task with relevant information
      adddatetime $new_task_id
      echo -e "This is a follow-up task from $new_task_id $old_task_desc" >> $PROJ_DIR/$new_task_id.task
      updateLastUpdate $new_task_id

      # close the original task
      update_task_status $project_name $task_id 80  
    fi
}

# Function to edit a task
edit_task() {
    local project_name=$1
    local task_id=$2
    local update_date=$(/bin/date)
    local task_file=$PROJ_DIR/$task_id.task

    # create a temporary copy of the task file
    cp -p $PROJ_DIR/${task_id}.task $PROJ_DIR/${task_id}.tmp
    ck1=`cksum $PROJ_DIR/$task_id.task|awk '{print $1}'`
    adddatetime $task_id
    ck2=`cksum $PROJ_DIR/$task_id.task|awk '{print $1}'`
    rm -f $PROJ_DIR/input_file.txt
    if [[ "$mytdprog" = "$default_mytdprog" ]]
    then
      $EDITOR $task_file
    else # for the Flask version, need to wait for the changes
      # wait for the input file
      while [[ ! -f $TASKS_DIR/input_file.txt ]]
      do
        sleep 1
      done
      if [[ -s $TASKS_DIR/input_file.txt ]]
      then
echo "$TASKS_DIR/input_file.txt is not empty"
ls -l $TASKS_DIR/input_file.txt
        cat $TASKS_DIR/input_file.txt >> $PROJ_DIR/$task_id.task
        echo -e "\n" >> $PROJ_DIR/$task_id.task
      fi
      rm -f $TASKS_DIR/input_file.txt
    fi
    ck3=`cksum $PROJ_DIR/$task_id.task|awk '{print $1}'`

    # if ck2 = ck3, then nothing changed, so we restore the ck1 version but update LastUpdated anyways
    erc=0
    if [[ $ck2 -eq $ck3 ]]
    then
      echo "Nothing changed."
      mv $PROJ_DIR/${task_id}.tmp $PROJ_DIR/$task_id.task
      ck4=`cksum $PROJ_DIR/$task_id.task|awk '{print $1}'`
      if [[ $ck4 -eq $ck1 ]]
      then
        echo "Restored original $PROJ_DIR/$task_id.task successfully"
      else
        echo "hmm: ck1=$ck1 ck2=$ck2 ck3=$ck3 ck4=$ck4"
        ls -l $PROJ_DIR/$task_id.task
      fi
      erc=1
    fi
    rm -f $PROJ_DIR/${task_id}.tmp
    updateLastUpdate $task_id
    echo ""
}

# Function to update the due date
update_due_date()
{
    local project_name=$1
    local task_id=$2
    local ndays=$3
    local old_due_date=`grep ^Due $PROJ_DIR/$task_id.task|awk '{print $2}'`
    local new_due_date=$(/bin/date -d "$ndays days" +%Y-%m-%d)
    local update_date=$(/bin/date)
    local task_file=$PROJ_DIR/$task_id.task
    if [[ "$old_due_date" != "$new_due_date" ]]
    then
      sed -i "s/^Due: .*/Due: $new_due_date/" $PROJ_DIR/$task_id.task
      adddatetime $task_id
      echo -e "CHG: Due Date->${old_due_date}->${new_due_date} " >> $PROJ_DIR/$task_id.task
      updateLastUpdate $task_id
    else
      echo "Due date is already $new_due_date"
    fi
    echo ""
set +x
}

# Function to list all open tasks in order of due date
list_tasks() {
    taskstatus=$1
    if [[ "$taskstatus" = "open" ]]
    then
      taskstati="11 30"
    else
      taskstati="$alltaskstati"
    fi

    local today=$(/bin/date +%Y-%m-%d)
    local tomorrow=$(/bin/date -d "1 day" +%Y-%m-%d)
    
    # create a string of all due dates but always add $today regardless, then sort again
    allduedates=`grep -h ^Due $PROJ_DIR/*.task|awk '{print $2}'`
    allduedates=`echo $today $allduedates`
    allduedates=`echo $allduedates|tr ' ' '\n'|sort -u`

    for taskstatus in $taskstati
    do
      if [[ $taskstatus -eq 11 ]]
      then
        sortorder="-k2,2 -k1,1" # due, task id
      else
        sortorder="-k1.114r" # last update
      fi
          
      if [[ $taskstatus -eq 11 ]]
      then
        duedates=$allduedates
        showdue=yes
      else
        duedates="20"
        showdue=no
      fi

      for duedate in $duedates
      do
        taskfiles=`find $PROJ_DIR -name "*.task" -exec grep -l "^Status: $taskstatus" {} \;|xargs grep -l "^Due: $duedate"`
        if [[ -n "$taskfiles" ]]
        then
          if [[ "$showdue" = "yes" ]]
          then
            echo -e "\n${bold}++++++++++++++"
            case $duedate in
              $today)     echo -e "! Today      !"
                          ;;
              $tomorrow)  echo -e "! Tomorrow   !"
                          ;;
                      *)  if [[ "$duedate" < "$today" ]]
                          then
                            echo -e "!  OVERDUE   !"
                          else
                            echo -e "! $duedate !"
                          fi;;
            esac
            echo -e "++++++++++++++${reset}"
          else
            echo -e "\n${bold}++++++++++++++"
            echo -e "! Status $taskstatus  !"
            echo -e "++++++++++++++${reset}"
          fi
          printf "${bold}%-16s %-12s %-6s %-60s %-12s %-25s %s${reset}\n" "Task Id" "Due" "Status" "Description" "created" "last update" "bug"
        else
          if [[ "$duedate" = "$today" ]] && [[ $overdue -eq 0 ]]
          then
            echo -e "\n${bold}*** At least for the moment, there's nothing else to do for today ***${reset}"
          fi
          continue
        fi
  
        for taskfile in $taskfiles
        do
          let t++
          local project_name=`dirname $taskfile|cut -f3 -d/`
          task_id=$(basename "$taskfile" .task)
          creation_date=$(/bin/date -d @"$task_id" +%Y-%m-%d)
          task_desc=`grep ^Task: $taskfile|cut -f2-20 -d" "`
          taskdue=`grep ^Due $taskfile|awk '{print $2}'`
          taskstatus=`grep ^Status $taskfile|awk '{print $2}'`
          lastupdate=`grep ^LastU $taskfile|awk '{print $2}'`
          bug=`grep ^Bug: $taskfile|awk '{print $2}'`

          case $taskstatus in
            30|80) bf="$curs";;
                *) bf="$reset";;
          esac
                                
          printf "${bf}%-16s %-12s %-6s %-60s %-12s %-25s %s${reset}\n" "$task_id" "$taskdue" "$taskstatus" "$task_desc" "$creation_date" "$lastupdate" "$bug"
        done | sort $sortorder
      done
      echo ""

    done
}

show_task_file()
{
    local project_name=$1
    local task_id=$2
    local task_file=$PROJ_DIR/$task_id.task

    cat $PROJ_DIR/$task_id.task
    echo ""
}

# Main menu
echo ""

if [[ ! -d $PROJ_DIR ]]
then
  create_project $project_name
  echo "Created project '$project_name'"
fi

while true; do
    unset option
    echo "$ver"
    echo "Selected project: '$project_name'"

    if [[ $justentered -eq 1 ]]
    then
      cat ${script_dir}/functions.txt|grep -v ^#
      list_tasks open
      justentered=0
    else
      if [[ $listtasks -eq 1 ]] && [[ ! "$saved_option" =~ "l" ]]
      then
        list_tasks open
      fi
    fi

    read -p "Choose an option: " option
    readrc=$? 
    if [[ $readrc -ne 0 ]]
    then
      bye
    fi
    echo ""
    if [[ -z "$option" ]]
    then
      continue
    fi
    set $option
    option=$1
    saved_option=$option
    shift

    case $option in
        c|ct) # leave ct in there for older clients
            usageXtoY 1 15 $# $option task_desc
            if [[ "$option" = "invalid" ]]
            then
              continue
            fi
            task_desc="$@"
            create_task $project_name $task_desc
            ;;
        cf|cft)
            usage1 $# $option task_id
            if [[ "$option" = "invalid" ]]
            then
              continue
            fi
            task_id=$1
            taskexists $task_id
            if [[ $trc -ne 0 ]]
            then
              continue
            fi
            create_followup_task $project_name $task_id
            ;;
        s|st)
            usage1 $# $option task_id
            if [[ "$option" = "invalid" ]]
            then
              continue
            fi
            task_id=$1
            taskexists $task_id
            if [[ $trc -ne 0 ]]
            then
              continue
            fi
            show_task_file $project_name $task_id
            ;;
        d|dt)
            usage1 $# $option task_id
            if [[ "$option" = "invalid" ]]
            then
              continue
            fi
            task_id=$1
            taskexists $task_id
            if [[ $trc -ne 0 ]]
            then
              continue
            fi
            delete_task $project_name $task_id
            ;;
        ud|udt)
            usage2 $# $option task_id Ndays
            if [[ "$option" = "invalid" ]]
            then
              continue
            fi
            task_id=$1
            ndays=$2
            taskexists $task_id
            if [[ $trc -ne 0 ]]
            then
              continue
            fi
            update_due_date $project_name $task_id $ndays
            ;;
        ub|ubt)
            usage2 $# $option task_id bug_id
            if [[ "$option" = "invalid" ]]
            then
              continue
            fi
            task_id=$1
            new_bug=$2
            taskexists $task_id
            if [[ $trc -ne 0 ]]
            then
              continue
            fi
            update_bug $project_name $task_id $new_bug
            ;;
        cl*|wip|wt|reopen)
            usage1 $# $option task_id
            if [[ "$option" = "invalid" ]]
            then
              continue
            fi
            task_id=$1
            case "$option" in
              cl*) new_status=80;;
              wt) new_status=30;;
              wip|reopen) new_status=11;;
            esac
            taskexists $task_id
            if [[ $trc -ne 0 ]]
            then
              continue
            fi
            update_task_status $project_name $task_id $new_status
            ;;
        e|et|ecl|eop|ewt)
            usage1 $# $option task_id
            if [[ "$option" = "invalid" ]]
            then
              continue
            fi
            task_id=$1
            taskexists $task_id
            if [[ $trc -ne 0 ]]
            then
              continue
            fi
            edit_task $project_name $task_id
            if [[ $erc -eq 0 ]]
            then
              case "$opt" in
                ecl) update_task_status $project_name $task_id 80; update_due_date $project_name $task_id 0 ;;
                eop) update_task_status $project_name $task_id 11; update_due_date $project_name $task_id 0 ;;
                ewt) update_task_status $project_name $task_id 30; update_due_date $project_name $task_id 0 ;;
              esac
            fi
            ;;
        l|lt)
            list_tasks open
            ;;
        la|lat)
            list_tasks
            ;;
        x|ex*)
            bye
            exit 0
            ;;
        h)  cat ${script_dir}/functions.txt|grep -v ^#
            ;;
        *)
            echo "Invalid option. Please try again."
            ;;
    esac
    echo "`/bin/date '+%Y-%m-%d %H:%M:%S'` $project_name $option $1 $2 $3" >> $TASKS_DIR/.mytd_history.log
    
done
