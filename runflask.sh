#! /bin/sh

# Get the directory of the script
script_path=$(realpath "$0")
script_dir=$(dirname "$script_path")
cd $script_dir

ver=`cat $script_dir/version.txt`
sed -i "s#<title>.*#<title>$ver</title>#g" $script_dir/templates/index.html
sed -i "s#<h1>.*#<h1>$ver</h1>#g" $script_dir/templates/index.html
export https_proxy=http://www-proxy.us.oracle.com:80
export PYTHONUSERBASE=$script_dir
export PYTHONPATH=$PYTHONUSERBASE
myenv=$script_dir/myenv
myenvbin=${myenv}/bin/
targetinst="--target=$script_dir"

cd $script_dir
rm -f get-pip.py*

pyver=`python -V`

if [[ ! -d flask ]]
then
  if [[ "$pyver" =~ "Python 3.6" ]]
  then
    wget https://bootstrap.pypa.io/pip/3.6/get-pip.py
  else
    if [[ "$pyver" =~ "Python 3.7" ]]
    then
      wget https://bootstrap.pypa.io/get-pip.py
    else
      echo "Some other Python version than 3.6 or 3.7 ? `echo $pyver`"
      exit 1
    fi
  fi
  echo "getting get-pip.py for $pyver"
  if [[ -n "${myenvbin}" ]]
  then
    python -m venv myenv
  fi
  rc=$?
  if [[ $rc -ne 0 ]]
  then
    echo create venv failed
    exit 4
  fi
  if [[ -f ${myenv}/bin/activate ]]
  then
    . ${myenv}/bin/activate
  fi
  ${myenv}/bin/python get-pip.py
  rc=$?
  if [[ $rc -ne 0 ]]
  then
    echo get-pip.py failed
    exit 2
  fi
  ${myenv}/bin/python -m ensurepip --upgrade
  rc=$?
  if [[ $rc -ne 0 ]]
  then
    echo ensurepip failed
    exit 3
  fi
  
  for p in Flask flask-socketio flask-talisman
  do
    echo ${myenv}/bin/pip install $targetinst $p
    ${myenv}/bin/pip install $targetinst $p > /dev/null
  done
else
  . ${myenv}/bin/activate
fi

${myenv}/bin/pip list
cd $script_dir
${myenv}/bin/python $script_dir/mytd.py
