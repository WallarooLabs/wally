#!/bin/bash

set -eEuo pipefail

if ! ps > /dev/null 2>&1; then
  if yum --help > /dev/null; then
    yum install procps -y
  fi
fi

pidtree() (
  set +u
  [ -n "${ZSH_VERSION:-}"  ] && setopt shwordsplit
  declare -A CHILDS
  while read P PP;do
    CHILDS[$PP]+=" $P"
  done < <(ps -e -o pid= -o ppid=)

  walk() {
    for i in ${CHILDS[$1]};do
      echo $i
      walk $i
    done
  }

  walk $1
  set -u
)

function cleanup {
  set +e
  while true; do
    pkill run_erl > /dev/null 2>&1
    pkill epmd > /dev/null 2>&1
    pkill sender > /dev/null 2>&1
    pkill data_receiver > /dev/null 2>&1
    PIDS_TO_KILL="$(pidtree $$)"
    PIDS_TO_KILL="$(ps -o pid= ${PIDS_TO_KILL})"
    if [[ "$PIDS_TO_KILL" == "" ]]; then
      break
    fi
    kill -9 $PIDS_TO_KILL > /dev/null 2>&1
  done
  set -e
}

function error_cleanup {
  local lineno=$1
  local msg=$2
  cleanup
  echo "ERROR! Failed at $lineno: $msg"
  exit 1
}

trap 'cleanup $LINENO "$BASH_COMMAND"' EXIT
trap 'error_cleanup $LINENO "$BASH_COMMAND"' SIGINT SIGTERM

LANG_TO_TEST=${1:-}

if [[ "$LANG_TO_TEST" == "" ]]; then
  echo "ERROR! Please pass language to run examples for as argument 1!"
  exit 1
fi

HERE=$(dirname "$(readlink -e "${0}")")
SOURCE_ACTIVATE="source $(readlink -e "${HERE}/../bin/activate")"
BASH_HEADER="#!/bin/bash -ex"

TESTING_TMP="${TMPDIR:-/tmp}/wallaroo-example-tester"

rm -rf "$TESTING_TMP"
mkdir -p "$TESTING_TMP"

# TODO: Add logic to keep testing all examples even if one fails and give a summary/report of whichever ones failed at end.
# TODO: Add ability to do the same for parts of the wallaroo book (install from source, vagrant, run an application, etc) where possible.
for dir in $(ls -d $(readlink -e "${HERE}/../examples")/${LANG_TO_TEST}/*/ | grep -v kafka | grep -v pony); do
  # call cleanup to kill any dangling processes started by this script to ensure a clean slate
  cleanup
  CHANGE_DIRECTORY="cd $dir"
  rm -f ${HERE}/../tmp/log/*
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
  echo "Scripts and log files can be found in: $MY_TMP"
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
      echo "Sleeping 60 seconds to let app run before shutdown (commands for last Shell)..."
      sleep 60
    fi
    echo "Running script of commands for Shell ${d}..."
    LAST_CMD=$(tail -n 1 "$MY_TMP/shell${d}.bash")
    "$MY_TMP/shell${d}.bash" > "$MY_TMP/shell${d}.log" 2>&1 &
    last_pid=$!
    subshell_finished="false"

    # wait for bash to have executed the last command before proceeding
    j=1
    while ! grep -F "+ $LAST_CMD" "$MY_TMP/shell${d}.log" > /dev/null 2>&1; 
    do
      # grep failed.. check to see if process is still running; if not, we might have a failure
      if ! ps -p $last_pid > /dev/null; then
        # process doesn't exist; check exit code
        # if non-zero then we have a failure
        wait ${last_pid}
        RET_CODE=$?
        if [[ "${RET_CODE}" != "0" ]]; then
          if [[ "$LAST_CMD" != "metrics_reporter_ui start" ]]; then
            echo "Error! Script for shell${d} failed with ${RET_CODE}!"
            exit 1
          fi
          if [[ $j -gt 3 ]]; then
            echo "Error! Script for shell${d} failed with ${RET_CODE}! Tried multiple times (because it is the metrics_ui) with no success!"
            exit 1
          fi
          ## we have a failure for metrics_ui... try it again in case it was a weird transient thing..
          cleanup
          rm -f ${HERE}/../tmp/log/*
          "$MY_TMP/shell${d}.bash" > "$MY_TMP/shell${d}.log.${j}" 2>&1 &
          last_pid=$!
          sleep 1
          let j=j+1
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
      i=1
      while [[ "$(tail -n 1 ${HERE}/../tmp/log/erlang.log.1)" != "iex(metrics_reporter_ui@127.0.0.1)1> " ]]; do
        sleep 1
        let i=i+1
        wait $last_pid
        RET_CODE=$?
        if [[ "${RET_CODE}" != "0" ]]; then
          if [[ $j -gt 3 ]]; then
            echo "Error! Script for shell${d} failed with ${RET_CODE}! Tried multiple times (because it is the metrics_ui) with no success!"
            exit 1
          fi
          ## we have a failure for metrics_ui... try it again in case it was a weird transient thing..
          cleanup
          rm -f ${HERE}/../tmp/log/*
          "$MY_TMP/shell${d}.bash" > "$MY_TMP/shell${d}.log.${j}" 2>&1 &
          last_pid=$!
          sleep 1
          let i=1
          let j=j+1
        fi
        if [[ $i -gt 15 ]]; then
          if [[ $j -gt 3 ]]; then
            echo "Error! Metrics reporter taking too long to start! Tried multiple times (because it is the metrics_ui) with no success!"
            exit 1
          fi
          ## we have a failure for metrics_ui... try it again in case it was a weird transient thing..
          cleanup
          rm -f ${HERE}/../tmp/log/*
          "$MY_TMP/shell${d}.bash" > "$MY_TMP/shell${d}.log.${j}" 2>&1 &
          last_pid=$!
          sleep 1
          let i=1
          let j=j+1
        fi
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
      RET_CODE=$?
      if [[ "${RET_CODE}" != "0" ]]; then
        echo "Error! Script for shell${d} failed with ${RET_CODE}!"
        exit 1
      fi
    fi

    my_pids="$my_pids $last_pid"
    let d=d+1
  done
  echo "Everything ran successfully. Cleaning up any errant processes..."
  # call cleanup to kill any dangling processes started by this script to ensure a clean slate
  cleanup
  echo "=================="
  echo "Done with example in directory: $dir"
  echo "=================="
  echo ""
  popd
done
