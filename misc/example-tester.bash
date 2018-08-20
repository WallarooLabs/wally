#!/bin/bash

set -eEuo pipefail

function cleanup {
  set +e
  while true; do
    PSAUX=$(ps aux | grep -v bash | tail -n +2 | grep -v tail)
    PSAUX=$(printf "$PSAUX" | wc -l)
    if [[ "$PSAUX" == "0" ]]; then
      break
    fi
    pkill run_erl
    pkill epmd
    PIDS_TO_KILL="$(ps fj | grep -v 'ps fj$' | grep -v "$0$" | grep -v grep | awk '{print $2 " " $3}' | grep " $$$" | awk '{print $1}' | tr '\n' ' ')"
    if [[ "$PIDS_TO_KILL" == "" ]]; then
      break
    fi
    kill -9 $PIDS_TO_KILL > /dev/null 2>&1
  done
  set -e
}

trap cleanup SIGINT SIGTERM EXIT

HERE=$(dirname "$(readlink -f "${0}")")
SOURCE_ACTIVATE="source $(readlink -f "${HERE}/../bin/activate")"
BASH_HEADER="#!/bin/bash -ex"

TESTING_TMP="${TMPDIR:-/tmp}/wally-up-testing"

rm -rf "$TESTING_TMP"
mkdir -p "$TESTING_TMP"

for dir in $(ls -d $(readlink -f "${HERE}/../examples")/*/*/ | grep -v kafka | grep -v pony); do
  CHANGE_DIRECTORY="cd $dir"
  rm -f ${HERE}/../bin/metrics_ui/usr/var/log/*
  rm -f /tmp/$(basename "$dir")-*
  MY_TMP="${TESTING_TMP}/examples/${dir##*examples/}"
  mkdir -p "$MY_TMP"
  pushd $dir
  rm -f "$MY_TMP/*"
  COMPILE_APP=
  if echo $dir | grep -Po '/go/' > /dev/null; then
    # if golang we want to compile the app
    COMPILE_APP="make"
  fi
  echo "=================="
  echo "Working on example in directory: $dir"
  echo "=================="
  c=1
  while [[ $c -le 100 ]]
  do 
    let old_c=c
    let c=c+1
    set +o pipefail
    SHELL_COMMAND=$(sed -n "/Shell $old_c:/,/Shell $c:/p" README.md  | sed -n '/```/,/```/p' | grep -v '```' | tr '\n' '@' | sed 's#\\@# #g' | tr '@' '\n' | tr -s ' ')
    set -o pipefail
    if [[ "$SHELL_COMMAND" == "" ]]; then
      let c=c-1
      break
    fi
    printf "$BASH_HEADER\n$CHANGE_DIRECTORY\n$SOURCE_ACTIVATE\n$COMPILE_APP\n$SHELL_COMMAND\n" > "$MY_TMP/shell${old_c}.bash"
    chmod +x "$MY_TMP/shell${old_c}.bash"
  done
  d=1
  my_pids=""
  while [[ $d -lt $c ]]
  do
    if [[ "$d" -eq "($c - 1)" ]]; then
      echo "Sleeping 60 seconds to let app run before shutdown..."
      sleep 60
    fi
    LAST_CMD=$(tail -n 1 "$MY_TMP/shell${d}.bash")
    "$MY_TMP/shell${d}.bash" > "$MY_TMP/shell${d}.log" 2>&1 &
    last_pid=$!
    subshell_finished="false"

    # wait for bash to have executed the last command before proceeding
    while ! grep -F "+ $LAST_CMD" "$MY_TMP/shell${d}.log" > /dev/null 2>&1; 
    do
      # grep failed.. check to see if process is still running; if not, we might have a failure
      if ! ps -p $last_pid > /dev/null; then
        # process doesn't exist; check exit code
        # if non-zero then we have a failure
        wait ${last_pid}
        RET_CODE=$?
        if [[ "${RET_CODE}" != "0" ]]; then
          echo "Error! Script for shell${d} failed with ${RET_CODE}!"
          exit 1
        else
          # if zero, we didn't see the output we were expecting and we have a failure
          # don't fail immediately in case grep didn't get to see the full log file yet
          # let it run through another loop before failing
          if [[ "$subshell_finished" == "true" ]]; then
            echo "Error! Script for shell${d} finished without expected output in log!"
            exit 1
          fi
          subshell_finished="true"
        fi
      else
        # sleep for 1 second to burn less CPU while waiting
        sleep 1
      fi
    done

    if [[ "$LAST_CMD" == "metrics_reporter_ui start" ]]; then
      ## starting metrics ui.. script will exit once done so wait for it
      wait $last_pid
      ## starting metrics ui script exits shell command before metrics ui is fully started due to forking
      ## check to make sure it's really started
      # sleep to avoid picking up first instance of start before restart/stop occur
      sleep 1
      while [[ "$(tail -n 1 ${HERE}/../bin/metrics_ui/usr/var/log/erlang.log.1)" != "iex(metrics_reporter_ui@127.0.0.1)1> " ]]; do
        sleep 1
      done
    fi

    # grep successul... check to make sure command didn't fail
    if ! ps -p $last_pid > /dev/null; then
      # process doesn't exist; check exit code
      # if non-zero then we have a failure
      wait ${last_pid}
      RET_CODE=$?
      if [[ "${RET_CODE}" != "0" ]]; then
        echo "Error! Script for shell${d} failed with ${RET_CODE}!"
        exit 1
      fi
    fi

    if [[ "$d" -eq "($c - 1)" ]]; then
      echo "Waiting for shutdown commands to finish..."
      wait ${last_pid}
    fi

    my_pids="$my_pids $last_pid"
    let d=d+1
  done
  if [[ "$(pgrep -P $$)" != "" ]]; then
    echo "Cleaning up errant child processes..."
    PIDS_TO_KILL=$(ps aux | grep -v bash | grep -v grep | grep -v awk | grep -v PID | grep -vF 'ps aux' | awk '{print $2}')
    # send sigterm to have them exit nicely
    kill -15 $PIDS_TO_KILL
    # wait for sigterm to do its thing and for child processes to exit cleanly
    sleep 1

    # if still not all exited
    if [[ "$(pgrep -P $$)" != "" ]]; then
      # TODO: should this be an error condition??
      echo "Killing stubborn child processes..."
      kill -9 $PIDS_TO_KILL
      if [[ "$(pgrep -P $$)" != "" ]]; then
        echo "WARNING: Not all processes ended between examples!!!"
        ps aux
      fi
    fi
  fi
  echo "=================="
  echo "Done with example in directory: $dir"
  echo "=================="
  echo ""
  popd
done
