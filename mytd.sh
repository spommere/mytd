#!/bin/bash

#debug=1

# Get the directory of the script
script_path=$(realpath "$0")
script_dir=$(dirname "$script_path")
cd $script_dir

mytdprog=`basename $0`

TASKS_DIR=${script_dir}/tasks
. ${script_dir}/env.sh

if [[ "$mytdprog" = "mytd_flask.sh" ]]
then
  set_formatting 0
  mkdir -p $TASKS_DIR/inbox
fi

mytdpid=$$
echo "Running $mytdprog pid $mytdpid"
nchg=0

# start mytd_service if requested
if [[ -n "$enable_mytd_service" ]] && [[ $enable_mytd_service -eq 1 ]]
then
  mytdssvcpid=`ps -ef|grep mytd_service.sh|grep -v grep|awk '{print $2}'`
  if [[ -z "$mytdsvcpid" ]]
  then
    ${script_dir}/mytd_service.sh $mytdpid 1>/dev/null 2>&1 &
  fi
fi

if [[ -z "$1" ]]
then
  project_name=$default_project_name
else
  project_name=$1
fi

PROJ_DIR=${script_dir}/tasks/$project_name

for task_status in $alltaskstati
do
  mkdir -p ${script_dir}/tasks/$project_name/$task_status >/dev/null
done

mecho ()
{ 
  if [[ -n "$debug" ]]
  then
    c=$*;
    echo "`/bin/date +'%Y-%m-%d %H:%M:%S.%N'|cut -c1-23`: $c"
  fi
}

bye()
{
  echo kthxbye
  exit 0
}

currdatetime()
{
  currdt=$(/bin/date)
}

findtaskfile()
{
  local task_id=$1
  taskfile=`ls $PROJ_DIR/*/${task_id}.task`
}

updateLastUpdate()
{
  local task_id=$1
  currdt=$(/bin/date +%Y-%m-%d_%H:%M:%S%Z)
  findtaskfile $task_id
  sed -i "s/^LastUpdate: .*/LastUpdate: $currdt/" $taskfile
}
  
adddatetime()
{
  local task_id=$1
  currdatetime
  findtaskfile $task_id
  echo -e "\n$currdt" >> $taskfile
}

taskexists()
{
  local task_id=$1
  findtaskfile $task_id
  trc=0
  if [[ ! -f $taskfile ]]
  then
    echo "Task $task_id does not exist"
    trc=1
  fi
}

## FUUNCTIONS

# Function to create a new project
create_project() {
    local project_name=$1
    mkdir -p $PROJ_DIR/
    echo "Project '$project_name' created."
    echo ""
    changed_flag=1
}

# Function to create a new task
create_task() {
    local project_name=$1
    shift
    #local task_desc=`echo "$*"|cut -c1-50|sed "s/\//-/g"`
    local task_desc=`echo "$*"|cut -c1-50`
    local wday=`/bin/date +%a`
    local defer=0
    case "$wday" in
      Sat) defer=2;;
      Sun) defer=1;;
        *) defer=0;;
    esac
    local due_date=$(/bin/date -d "+${defer} days" +%Y-%m-%d)
    # task_id is Unix time
    local task_id=$(/bin/date +%s)
    local task_file=$PROJ_DIR/$default_task_status/$task_id.task
    
    # Check if project exists, if not, create it
    if [ ! -d $PROJ_DIR/ ]; then
        create_project $project_name
    fi
    
    echo -e "Task: $task_desc\nDue: $due_date\nStatus: $default_task_status\nBug: \nLastUpdate: \n" > $task_file
    adddatetime $task_id
    echo "Task created" >> $task_file
    updateLastUpdate $task_id
    echo ""
    changed_flag=1
}

# Function to delete an individual task
delete_task() {
    local project_name=$1
    local task_id=$2
    findtaskfile $task_id
    rm -f $taskfile
    echo "Task '$task_id' deleted from project '$project_name'."
    echo ""
    changed_flag=1
}

# Function to update a task status
update_task_status() {
    local project_name=$1
    local task_id=$2
    local new_status=$3
    findtaskfile $task_id
    local old_status=`grep ^Status $taskfile|awk '{print $2}'`

    if [[ "$old_status" != "$new_status" ]]
    then
      sed -i "s/^Status: .*/Status: $new_status/" $taskfile
      adddatetime $task_id
      echo -e "CHG: Status->${old_status}->${new_status} " >> $taskfile
      updateLastUpdate $task_id
      mv $taskfile $PROJ_DIR/${new_status}
      changed_flag=1
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
    findtaskfile $task_id
    local old_bug=`grep ^Bug: $taskfile|awk '{print $2}'`

    if [[ "$old_bug" != "$new_bug" ]]
    then
      sed -i "s/^Bug: .*/Bug: $new_bug/" $taskfile
      adddatetime $task_id
      echo -e "CHG: Bug->${old_bug}->${new_bug} " >> $taskfile
      updateLastUpdate $task_id
      changed_flag=1
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
    findtaskfile $task_id
    if [[ -f $taskfile ]]
    then
      old_task_desc=`grep ^Task: $taskfile|awk '{print $2,$3,$4,$5,$6,$7,$8,$9,$10}'`

      # create a follow-up task
      create_task $project_name "Follow-up: $old_task_desc"
      new_task_id=`ls -1tr $PROJ_DIR/${default_task_status}/|tail -1|cut -f1 -d'.'`

      # update original task with relevant information
      adddatetime $task_id
      echo -e "Created a follow-up task $new_task_id $new_task_desc" >> $taskfile

      # update the new task with relevant information
      findtaskfile $new_task_id
      adddatetime $new_task_id
      echo -e "This is a follow-up task from $new_task_id $old_task_desc" >> $taskfile
      updateLastUpdate $new_task_id

      # close the original task
      update_task_status $project_name $task_id $status_closed  
    fi
}

# Function to edit a task
edit_task() {
    local project_name=$1
    local task_id=$2
    local update_date=$(/bin/date)
    findtaskfile $task_id

    # create a temporary copy of the task file
    cp -p $taskfile ${taskfile}.tmp
    ck1=`cksum $taskfile|awk '{print $1}'`
    adddatetime $task_id
    ck2=`cksum $taskfile|awk '{print $1}'`
    rm -f $PROJ_DIR/input_file.txt
    if [[ "$mytdprog" = "$default_mytdprog" ]]
    then
      $EDITOR $taskfile
    else # for the Flask version, need to wait for the changes
      # wait for the input file
      while [[ ! -f $TASKS_DIR/input_file.txt ]]
      do
        sleep 1
      done
      if [[ -s $TASKS_DIR/input_file.txt ]]
      then
        cat $TASKS_DIR/input_file.txt >> $taskfile
        echo -e "\n" >> $taskfile
      fi
      rm -f $TASKS_DIR/input_file.txt
    fi
    ck3=`cksum $taskfile|awk '{print $1}'`

    # if ck2 = ck3, then nothing changed, so we restore the ck1 version but update LastUpdated anyways
    if [[ $ck2 -eq $ck3 ]]
    then
      echo "Nothing changed."
      mv ${taskfile}.tmp $taskfile
      ck4=`cksum $taskfile|awk '{print $1}'`
      if [[ $ck4 -eq $ck1 ]]
      then
        echo "Restored original $taskfile successfully"
      else
        echo "hmm: ck1=$ck1 ck2=$ck2 ck3=$ck3 ck4=$ck4"
        ls -l $taskfile
      fi
    fi
    changed_flag=1
    rm -f ${taskfile}.tmp
    updateLastUpdate $task_id
    echo ""
}

# Function to update the due date
update_due_date()
{
    local project_name=$1
    local task_id=$2
    findtaskfile $task_id
    local ndays=$3
    local old_due_date=`grep ^Due $taskfile|awk '{print $2}'`
    local new_due_date=$(/bin/date -d "$ndays days" +%Y-%m-%d)
    local update_date=$(/bin/date)

    if [[ "$old_due_date" != "$new_due_date" ]]
    then
      sed -i "s/^Due: .*/Due: $new_due_date/" $taskfile
      adddatetime $task_id
      echo -e "CHG: Due Date->${old_due_date}->${new_due_date} " >> $taskfile
      updateLastUpdate $task_id
      changed_flag=1
    else
      echo "Due date is already $new_due_date"
    fi
    echo ""
set +x
}

# Function to list all open tasks in order of due date
list_tasks()
{
  mecho list_taskes enter
  taskstatus=$1
  if [[ "$taskstatus" = "open" ]]
  then
    taskstati="$status_wip $status_wait"
  else
    taskstati="$alltaskstati"
  fi

  local today=$(/bin/date +%Y-%m-%d)
  local tomorrow=$(/bin/date -d "1 day" +%Y-%m-%d)
  
  # create a string of all due dates but always add $today regardless, then sort again
  allduedates=`grep -h ^Due $PROJ_DIR/*/*.task 2>/dev/null|awk '{print $2}'`
  allduedates=`echo $today $allduedates`
  allduedates=`echo $allduedates|tr ' ' '\n'|sort -u`

  mecho for_taskstatus begin 
  for taskstatus in $taskstati
  do
    mecho taskstatus=$taskstatus
    if [[ $taskstatus -eq $status_wip ]]
    then
      sortorder="-k2,2 -k1,1" # due, task id
      duedates=$allduedates
      showdue=yes
    else
      sortorder="-k1.114r" # last update
      duedates="20"
      showdue=no
    fi
        
    overdue=0
    overdue_shown=0
    mecho for_duedate begin
    for duedate in $duedates
    do
      mecho find_taskfiles begin $duedate
      taskfiles=`find $PROJ_DIR/$taskstatus -name "*.task" |xargs grep -l "^Due: $duedate"`
      mecho find_taskfiles end $duedate
      if [[ -n "$taskfiles" ]]
      then
        if [[ "$showdue" = "yes" ]]
        then
          echo -e "\n${bold}++++++++++++++++++++++++"
          case $duedate in
            $today)     echo -e "! Today                !"
                        ;;
            $tomorrow)  echo -e "! Tomorrow             !"
                        ;;
                    *)  if [[ "$duedate" < "$today" ]]
                        then
                          echo -e "!  OVERDUE $duedate  !"
                          overdue=1
                        else
                          echo -e "! $duedate           !"
                        fi;;
          esac
          echo -e "++++++++++++++++++++++++${reset}"
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

      mecho for_taskfile begin
      for taskfile in $taskfiles
      do
        mecho taskfile=$taskfile
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
          $status_wait|$status_closed) bf="$curs";;
              *) bf="$reset";;
        esac
                              
        printf "${bf}%-16s %-12s %-6s %-60s %-12s %-25s %s${reset}\n" "$task_id" "$taskdue" "$taskstatus" "$task_desc" "$creation_date" "$lastupdate" "$bug"
      done | sort $sortorder
      mecho for_taskfile end
    done
    mecho for_duedate end
    echo ""
  done
  mecho for_taskstatus end
}


find_tasks()
{
  local project_name=$1
  shift
  cd $PROJ_DIR
  search_command="grep -il \"$1\" */*.task"
  shift

  # Loop through the remaining arguments and add them to the search command
  for string in "$@"
  do
    search_command="$search_command | xargs grep -il \"$string\""
  done

  # Execute the search command
  taskfiles=`eval $search_command`
  if [[ -z "$taskfiles" ]]
  then
     echo -e "${bold}Nothing found${reset}"
   else
     for taskfile in `eval $search_command`
     do
       echo -e "${bold}`grep -H ^Task: $taskfile`${reset}"
     done
  fi
  cd $script_dir
  echo ""
}

show_task_file()
{
    local project_name=$1
    local task_id=$2
    findtaskfile $task_id
    less $taskfile
    echo ""
}

# Main menu
echo ""

# set changed_flag
changed_flag=0

if [[ ! -d $PROJ_DIR ]]
then
  create_project $project_name
  echo "Created project '$project_name'"
fi

while true
do
  if [[ $changed_flag -eq 1 ]]
  then
    let nchg++
    # backup every 10th change
    if [[ $(( nchg % bkfreq )) -eq 0 ]]
    then
      backuptasks
      let nchg=0
    fi
  fi

  echo -e "${bold}$ver${reset}"
  echo "Selected project: '$project_name'"

  if [[ $justentered -eq 1 ]]
  then
    cat ${script_dir}/functions.txt|grep -v ^#
    echo "Available task stati: $alltaskstati"
    list_tasks open
    justentered=0
  else
    if [[ $listtasks -eq 1 ]] && [[ ! "$saved_option" =~ ^l ]]
    then
      list_tasks open
    fi
  fi

  #unset option
  read -e -p "Choose an option: " option
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

      # creating a task
      c|ct) # leave ct in there for older clients
          usageXtoY 1 15 $# $option task_desc
          if [[ "$option" = "invalid" ]]
          then
            continue
          fi
          task_desc="$@"
          create_task $project_name $task_desc
          ;;

      # creating a follow-up task
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

      # showing a task
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
          changed_flag=0
          ;;

      # deleting a task
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

      # deleting a task
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

      # updating a task with a bug number
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

      # updating a task status with shortcuts
      cl|wip|wt|op)
          usage1 $# $option task_id
          if [[ "$option" = "invalid" ]]
          then
            continue
          fi
          task_id=$1
          case "$option" in
            cl) new_status=$status_closed;;
            wt) new_status=$status_wait;;
            wip|op) new_status=$status_wip;;
          esac
          taskexists $task_id
          if [[ $trc -ne 0 ]]
          then
            continue
          fi
          update_task_status $project_name $task_id $new_status
          ;;

      # calling $EDITOR and updating a task status with shortcuts
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
          if [[ $changed_flag -eq 1 ]] # changed
          then
            case "$opt" in
              ecl) update_task_status $project_name $task_id $status_closed ;;
              eop) update_task_status $project_name $task_id $status_wip ;;
              ewt) update_task_status $project_name $task_id $status_wait ;;
            esac
            update_due_date $project_name $task_id 0
          fi
          ;;

      # listing open tasks
      l|lt)
          list_tasks open
          ;;

      # listing all tasks
      la|lat)
          list_tasks
          ;;

      # searching/finding task by string(s)
      f)
          usageXtoY 1 5 $#
          if [[ "$option" = "invalid" ]]
          then
            continue
          fi
          find_tasks $project_name "$@"
          ;;

      # exiting the script
      x|ex*)
          usage0 $#
          backuptasks
          bye
          ;;

      # HELP ! 
      h)  cat ${script_dir}/functions.txt|grep -v ^#
          ;;

      # anything else
      *)
          echo "Invalid option. Please try again."
          ;;
  esac
    
  echo "`/bin/date '+%Y-%m-%d %H:%M:%S'` $project_name $option $1 $2 $3" >> $TASKS_DIR/.mytd_history.log
    
done
