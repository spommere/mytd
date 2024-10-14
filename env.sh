#! /bin/sh

ver=`cat $script_dir/version.txt`
EDITOR="vi +$"
default_mytdprog=mytd.sh
flask_mytdprog=mytd_flask.sh

justentered=1

# list tasks after each non-list command
listtasks=0
listtasks=1

# formating headers and other things
#formatting=0
formatting=1

set_formatting()
{
  if [[ $1 -eq 0 ]]
  then
    bold=""
    curs=""
    reset=""
  else
    bold="\033[1m" # bold
    curs="\033[3m" # cursive
    reset="\033[0m" # reset
  fi
}

set_formatting $formatting

# experimental
enable_mytd_service=0
#enable_mytd_service=1

#
# USAGE stuff
#

usagecheck()
{
  cu=$1
  if [ $x -gt $y ]
  then
    echo usagecheck : x greater than y
    exit
  fi

  if [ $cu -lt $NMIN ]
  then
    echo usagecheck : at least $NMIN parameters expected
    exit
  fi

  if [ $cu -gt $NMAX ]
  then
    echo "usagecheck : at most $NMAX parameters expected ($cu)"
    exit
  fi
}

usageXtoY()
{
  NMIN=3
  NMAX=15
  x=$1
  y=$2
  c=$3
  opt=$4
  usagecheck $#
  p[1]=${5:-parameter1}
  p[2]=${6:-parameter2}
  p[3]=${7:-parameter3}
  p[4]=${8:-parameter4}
  p[5]=${9:-parameter5}
  p[6]=${10:-parameter6}
  p[7]=${11:-parameter7}
  p[8]=${12:-parameter8}
  p[9]=${13:-parameter9}
  if [ $c -lt $x -o $c -gt $y ]
  then
    for ((j=$x;j<=$y;j++))
    do
      str="usage: $opt "
      for ((i=1;i<=$j;i++))
      do
        str="${str}<${p[$i]}> "
      done
      echo "$str"
    done
    option=invalid
  fi
}

usage1()
{
  c=$1
  opt=$2
  p1=${3:-parameter1}
  if [ $c -ne 1 ]
  then
    echo "usage: $opt <$p1>"
    option=invalid
  fi
}

usage2()
{
  c=$1
  opt=$2
  p1=${3:-parameter1}
  p2=${4:-parameter2}
  if [ $c -ne 2 ]
  then
    echo "usage: $opt <${p1}> <${p2}>"
    option=invalid
  fi
}
