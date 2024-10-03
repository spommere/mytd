#!/bin/bash

TASKS_DIR="./tasks"
. ./env

mkdir -p "$TASKS_DIR"

alltaskstati="11 30 80"
if [[ -z "$1" ]]
then
  project_name=Work
else
  project_name=$1
fi

# Function to create a new project
create_project() {
    local project_name=$1
    mkdir -p "$TASKS_DIR/$project_name"
    echo "Project '$project_name' created."
    echo ""
}

# Function to create a new task
create_task() {
    local project_name=$1
    local ndays=$2
    shift;shift
    local task_name=`echo "$*"|cut -c1-52`
    local due_date=$(/bin/date -d "+${ndays} days" +%Y-%m-%d)
    local task_id=$(/bin/date +%s)
    local task_file="$TASKS_DIR/$project_name/$task_id.task"
    
    # Check if project exists, if not, create it
    if [ ! -d "$TASKS_DIR/$project_name" ]; then
        create_project "$project_name"
    fi
    
    echo -e "Task: $task_name\nDue: $due_date\nStatus: 11" > "$task_file"
    echo "Task '$task_id $task_name' created in project '$project_name'."
    echo ""
}

# Function to delete an individual task; actually we archive it
delete_task() {
    local project_name=$1
    local task_id=$2
    mkdir -p $TASKS_DIR/$project_name/.archive 2>/dev/null
    #rm -f "$TASKS_DIR/$project_name/$task_id.task"
    mv $TASKS_DIR/$project_name/$task_id.task $TASKS_DIR/$project_name/.archive
    echo "Task '$task_id' deleted from project '$project_name'."
    echo ""
}

# Function to update a task status
update_task_status() {
    local project_name=$1
    local task_id=$2
    local new_status=$3
    local update_date=$(/bin/date)
    local old_status=`grep ^Status $TASKS_DIR/$project_name/$task_id.task|awk '{print $2}'`
    sed -i "s/^Status: .*/Status: $new_status/" "$TASKS_DIR/$project_name/$task_id.task"
    echo "Task Edited '$task_id' status updated to '$new_status'."
    echo -e "\n$update_date" >> $TASKS_DIR/$project_name/$task_id.task
    echo -e "CHG: Status->${old_status}->${new_status} " >> $TASKS_DIR/$project_name/$task_id.task
    echo ""
}

# Function to close one task and create a follow-up task
create_followup_task()
{
    local project_name=$1
    local ndays=$2
    local task_id=$3
    if [[ -f $TASKS_DIR/$project_name/$task_id.task ]]
    then
      update_task_status $project_name $task_id 80  
      old_taskdesc=`grep ^Task $TASKS_DIR/$project_name/$task_id.task|awk '{print $2,$3,$4,$5,$6,$7,$8,$9,$10}'`
      create_task $project_name $ndays "Follow-up: $old_taskdesc"
      new_task_id=`ls -1tr $TASKS_DIR/$project_name|tail -1|cut -f1 -d'.'`
      local update_date=$(/bin/date)
      echo -e "\n$update_date" >> $TASKS_DIR/$project_name/$new_task_id.task
      echo -e "This is a follow-up task from $new_task_id $old_taskdesc" >> $TASKS_DIR/$project_name/$new_task_id.task
    fi
}

# Function to edit a task
edit_task() {
    local project_name=$1
    local task_id=$2
    local update_date=$(/bin/date)
    local task_file="$TASKS_DIR/$project_name/$task_id.task"
    echo -e "\n$update_date" >> "$task_file"
    vi "$task_file"
    echo ""
}

update_due_date()
{
    local project_name=$1
    local task_id=$2
    local ndays=$3
    local old_due_date=`grep ^Due $TASKS_DIR/$project_name/$task_id.task|awk '{print $2}'`
    local new_due_date=$(/bin/date -d "+$ndays days" +%Y-%m-%d)
    local update_date=$(/bin/date)
    local task_file="$TASKS_DIR/$project_name/$task_id.task"
    echo "Task Edited '$task_id' due date updated to '$new_due_date'."
    echo -e "\n$update_date" >> "$task_file"
    echo -e "CHG: Due Date->${old_due_date}->${new_due_date} " >> $TASKS_DIR/$project_name/$task_id.task
    echo ""
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
    t=0
    for taskstatus in $taskstati
    do
      taskfiles=`find "$TASKS_DIR" -name "*.task" -exec grep -l "Status: $taskstatus" {} \;`
      if [[ -n "$taskfiles" ]]
      then
        printf "%-16s %-60s %-12s %-12s %-6s\n" "task_id" "taskdesc" "created" "due" "status"
      else
        continue
      fi
      for taskfile in $taskfiles
      do
        let t++
        local project_name=`dirname $taskfile|cut -f3 -d/`
        task_id=$(basename "$taskfile" .task)
        creation_date=$(/bin/date -d @"$task_id" +%Y-%m-%d)
        taskdesc=`grep ^Task $taskfile|cut -f2-20 -d" "`
        taskdue=`grep ^Due $taskfile|awk '{print $2}'`
        taskstatus=`grep ^Status $taskfile|awk '{print $2}'`
        printf "%-16s %-60s %-12s %-12s %-6s\n" "$task_id" "$taskdesc" "$creation_date" "$taskdue" "$taskstatus"
      done | sort -k1
      echo ""
    done
}

# Main menu
echo ""
while true; do
    unset option
    echo "Task Management App ($ver)"
    echo "Selected project: '$project_name'"
    if [[ ("$showmenu" = "once" && $shownmenu -eq 0) || "$showmenu" = "always"  ]]
    then
      cat ./functions
      shownmenu=1
    fi
    read -p "Choose an option: " option
    echo ""
    if [[ -z "$option" ]]
    then
      continue
    fi
    set $option
    option=$1
    shift

    case $option in
        cft)
            usage2 $# $option ndays task_name
            if [[ "$option" = "invalid" ]]
            then
              continue
            fi
            ndays=$1
            task_id=$2
            create_followup_task "$project_name" $ndays "$task_id"
            list_tasks
            ;;
        ct)
            usageXtoY 2 15 $# $option ndays task_name
            if [[ "$option" = "invalid" ]]
            then
              continue
            fi
            ndays=$1
            shift
            task_name="$@"
            create_task "$project_name" $ndays "$task_name"
            list_tasks
            ;;
        dt)
            usage1 $# $option task_id
            if [[ "$option" = "invalid" ]]
            then
              continue
            fi
            task_id=$1
            delete_task "$project_name" "$task_id"
            list_tasks
            ;;
        uts)
            usage2 $# $option task_id new_status
            if [[ "$option" = "invalid" ]]
            then
              continue
            fi
            task_id=$1
            new_status=$2
            update_task_status "$project_name" "$task_id" "$new_status"
            list_tasks
            ;;
        et)
            usage1 $# $option task_id
            if [[ "$option" = "invalid" ]]
            then
              continue
            fi
            task_id=$1
            edit_task "$project_name" "$task_id"
            ;;
        l|lt)
            list_tasks open
            ;;
        lta)
            list_tasks
            ;;
        utd)
            usage2 $# $option task_name Ndays
            if [[ "$option" = "invalid" ]]
            then
              continue
            fi
            task_id=$1
            ndays=$2
            update_due_date "$project_name" "$task_id" $ndays
            list_tasks
            ;;
        e|ex|exit)
            echo kthxbye
            exit 0
            ;;
        r)   ./$0
             exit 0
             ;;
        *)
             echo "Invalid option. Please try again."
             #break
             ;;
    esac
done
