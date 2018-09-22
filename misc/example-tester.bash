#!/bin/bash

set -eEuo pipefail

# check if command exists
have_cmd() {
  command -v "$1" > /dev/null 2>&1
}

# install sudo if it doesn't exist
if ! have_cmd sudo; then
  if have_cmd yum; then
    yum install sudo -y
  else
    apt-get update
    apt-get install sudo -y
  fi
fi

# install ps if it doesn't exist
if ! have_cmd ps; then
  if have_cmd yum; then
    sudo yum install procps -y
  else
    sudo apt-get update
    sudo apt-get install procps -y
  fi
fi

# install route if it doesn't exist
if ! have_cmd route; then
  if have_cmd yum; then
    sudo yum install net-tools -y
  else
    sudo apt-get update
    sudo apt-get install net-tools -y
  fi
fi

# install ip if it doesn't exist
if ! have_cmd ip; then
  if have_cmd yum; then
    sudo yum install iproute -y
  else
    sudo apt-get update
    sudo apt-get install iproute2 -y
  fi
fi

DOCKER_PREFIX="bash -c "

# install docker if it doesn't exist
if ! have_cmd docker; then
  if [ -f /.dockerenv ]; then
    # if in docker, download docker client only
    DOCKERVERSION=18.06.1-ce
    curl -fsSLO https://download.docker.com/linux/static/stable/x86_64/docker-${DOCKERVERSION}.tgz
    tar xzvf docker-${DOCKERVERSION}.tgz --strip 1 \
                 -C /usr/local/bin docker/docker
    rm docker-${DOCKERVERSION}.tgz
    DOCKER_PREFIX="bash -c "
  else
    # if in vagrant, do a full docker install
    curl -fsSL get.docker.com -o /tmp/get-docker.sh
    sh /tmp/get-docker.sh
    sudo groupadd -f docker
    sudo usermod -aG docker "$USER"

    # ensure commands we run later will be allowed to use the docker socket
    DOCKER_PREFIX="sg docker -c "
  fi
fi

# get all pids that are children of current shell
pidtree() (
  set +u
  [ -n "${ZSH_VERSION:-}"  ] && setopt shwordsplit
  declare -A CHILDS
  while read -r P PP;do
    CHILDS[$PP]+=" $P"
  done < <(ps -e -o pid= -o ppid=)

  walk() {
    for i in ${CHILDS[$1]};do
      echo "$i"
      walk "$i"
    done
  }

  walk "$1"
  set -u
)

# kill dangling processes
function cleanup {
  set +e
  while true; do
    pkill run_erl > /dev/null 2>&1
    pkill epmd > /dev/null 2>&1
    pkill sender > /dev/null 2>&1
    pkill data_receiver > /dev/null 2>&1
    PIDS_TO_KILL="$(pidtree $$)"
    # shellcheck disable=SC2086
    PIDS_TO_KILL="$(ps -o pid= ${PIDS_TO_KILL})"
    if [[ "$PIDS_TO_KILL" == "" ]]; then
      break
    fi
    # shellcheck disable=SC2086
    kill -9 $PIDS_TO_KILL > /dev/null 2>&1
  done
  set -e
}

# kill dangling processes and then exit with error
function error_cleanup {
  local lineno=$1
  local msg=$2
  cleanup
  echo "ERROR! Failed at $lineno: $msg"
  exit 1
}

trap 'cleanup $LINENO "$BASH_COMMAND"' EXIT
trap 'error_cleanup $LINENO "$BASH_COMMAND"' SIGINT SIGTERM

WALLAROO_EXAMPLE_TESTER_NAME=wallaroo-example-tester

# function to log to file
log() {
  tmp_cmd="echo \"${WALLAROO_EXAMPLE_TESTER_NAME}: $1\"  2>&1 | tee -a $LOG_FILE"
  eval "$tmp_cmd"
}

LANG_TO_TEST=${1:-*}
EXAMPLE_TO_TEST=${2:-*}

HERE=$(dirname "$(readlink -e "${0}")")
WALLAROO_DIR="$(readlink -e "${HERE}/..")"
SOURCE_ACTIVATE="source $(readlink -e "${WALLAROO_DIR}/bin/activate")"
BASH_HEADER="#!/bin/bash -ex"

TESTING_TMP="${TMPDIR:-/tmp}/wallaroo-example-tester"

# function to do the actual parsing/running of example READMEs
parse_and_run() {
  file_to_parse="$1"
  file_dir="$(dirname "$file_to_parse")"

  CHANGE_DIRECTORY="cd '$file_dir'"
  # if the kafka cluster git directory exists, try and run cluster down just in case it was left running and then remove the directory
  if [ -e /tmp/local-kafka-cluster/ ]; then
    pushd /tmp/local-kafka-cluster/
    ${DOCKER_PREFIX} "./cluster down" || echo "Killing kafka cluster failed..."
    popd
    rm -rf /tmp/local-kafka-cluster/
  fi

  # delete tmp files
  rm -f "${WALLAROO_DIR}/tmp/log/"*
  rm -f "/tmp/$(basename "$file_dir")-"*

  # set/create/clean temp directory for this example
  MY_TMP="${TESTING_TMP}/${file_dir##*$(basename "${WALLAROO_DIR}")/}"
  mkdir -p "$MY_TMP"
  pushd "$file_dir"
  rm -f "$MY_TMP/"*
  LOG_FILE="$MY_TMP/${WALLAROO_EXAMPLE_TESTER_NAME}.log"
  RESULT_FILE="${MY_TMP}/result"
  # assume failure; will get changed to success if example runs successfully
  echo "FAILURE" > "${RESULT_FILE}"

  # assume we need to compile app
  COMPILE_APP="make"
  if echo "$file_dir" | grep -Po '/python/' > /dev/null; then
    # if python we don't want to compile the app
    COMPILE_APP=
  fi
  log "=================="
  log "Working on example in directory: $file_dir"
  log "$(date)"
  log "=================="
  log "Scripts and log files can be found in: $MY_TMP"

  # loop through to generate scripts for each `shell`s commands
  c=1
  while [[ $c -le 100 ]]
  do
    (( old_c=c ))
    (( c=c+1 ))
    # temporarily disable pipefail and then extract out shell commands for current shell
    set +o pipefail
    # shellcheck disable=SC2016
    SHELL_COMMAND=$(sed -n "/Shell $old_c:/,/Shell $c:/p" "${file_to_parse}"  | sed -n '/```/,/```/p' | grep -v '```' | tr '\n' '@' | sed 's#\\@# #g' | tr '@' '\n' | tr -s ' ')
    set -o pipefail

    # if no shell commands for current shell, assume we're at end of README
    if [[ "$SHELL_COMMAND" == "" ]]; then
      # decrement shell count and break out of while loop because we're done generating all shell scripts
      (( c=c-1 ))
      break
    fi

    # generate shell script and make it as executable
    printf "%s\n%s\n%s\n%s\n%s\n" "$BASH_HEADER" "$CHANGE_DIRECTORY" "$SOURCE_ACTIVATE" "$COMPILE_APP" "$SHELL_COMMAND" > "$MY_TMP/shell${old_c}.bash"
    chmod +x "$MY_TMP/shell${old_c}.bash"
  done
  d=1
  my_pids=""
  # loop through to run scripts for each `shell`s commands to simulate a user following the README instructions
  while [[ $d -lt $c ]]
  do
    # if it's the last shell script, sleep for 60 seconds because by convention the last shell script has shutdown commands
    if [[ "$d" -eq "($c - 1)" ]]; then
      log "Sleeping 60 seconds to let app run before shutdown (commands for last Shell)..."
      sleep 60
    fi
    log "Running script of commands for Shell ${d}..."

    # get last command from shell script
    ORIG_LAST_CMD=$(tail -n 1 "$MY_TMP/shell${d}.bash")
    # remove leading whitespace characters
    ORIG_LAST_CMD="${ORIG_LAST_CMD#"${ORIG_LAST_CMD%%[![:space:]]*}"}"
    # remove trailing whitespace characters
    ORIG_LAST_CMD="${ORIG_LAST_CMD%"${ORIG_LAST_CMD##*[![:space:]]}"}"

    # get likely last command taking into account pipes and variables
    LAST_CMD=$(echo "${ORIG_LAST_CMD}" | awk -F '|' '{print $NF}' | awk -F '$' '{print $1}')
    # remove leading whitespace characters
    LAST_CMD="${LAST_CMD#"${LAST_CMD%%[![:space:]]*}"}"
    # remove trailing whitespace characters
    LAST_CMD="${LAST_CMD%"${LAST_CMD##*[![:space:]]}"}"

    # run script for this shell taking into account docker security group
    SHELL_LOG_FILE="$MY_TMP/shell${d}.log"
    ${DOCKER_PREFIX} "$MY_TMP/shell${d}.bash" > "$SHELL_LOG_FILE" 2>&1 &
    last_pid=$!
    subshell_finished="false"

    # wait for bash to have executed the last command before proceeding
    j=1
    i=1
    grep_match="+ $LAST_CMD
+$LAST_CMD"
    while ! grep -F "$grep_match" "$SHELL_LOG_FILE" > /dev/null 2>&1;
    do
      # grep failed.. check to see if process is still running; if not, we might have a failure
      if ! ps -p $last_pid > /dev/null; then
        # process doesn't exist; check exit code
        # if non-zero then we have a failure
        RET_CODE=0
        wait ${last_pid} || RET_CODE=$?
        if [[ "${RET_CODE}" != "0" ]]; then
          # process failed; if not metrics ui, stop running this example and move on to next one
          if [[ "$LAST_CMD" != "metrics_reporter_ui start" ]]; then
            log "Error! Script for shell${d} failed with ${RET_CODE}!"
            if [[ "${VERBOSE_ERROR:-}" == "true" ]]; then
              cat "$SHELL_LOG_FILE"
            fi
            return
          fi
          # process failed; if metrics ui, retry a few times just in case of a transient issue (port conflict, etc)
          if [[ $j -gt 3 ]]; then
            log "Error! Script for shell${d} failed with ${RET_CODE}! Tried multiple times (because it is the metrics_ui) with no success!"
            if [[ "${VERBOSE_ERROR:-}" == "true" ]]; then
              cat "$SHELL_LOG_FILE"
            fi
            return
          fi
          ## we have a failure for metrics_ui... try it again in case it was a weird transient thing..
          # call cleanup to kill any dangling processes since nothing should be running at this point
          cleanup
          rm -f "${WALLAROO_DIR}/tmp/log/"*
          SHELL_LOG_FILE="$MY_TMP/shell${d}.log.${j}"
          ${DOCKER_PREFIX} "$MY_TMP/shell${d}.bash" > "$SHELL_LOG_FILE" 2>&1 &
          last_pid=$!
          sleep 1
          (( j=j+1 ))
        else
          # if zero, we didn't see the output we were expecting and we have a failure
          # don't fail immediately in case grep didn't get to see the full log file yet
          # let it run through another loop before failing
          if [[ "$subshell_finished" == "true" ]]; then
            # check if the last command was a command with a variable or pipe in it
            if [[ "${LAST_CMD}" != "${ORIG_LAST_CMD}" ]]; then
              # if yes, don't fail but assume things were started successfully and print warning before continuing
              log "Warning! Script for shell${d} finished successfully without expected output in log! Assuming everything is running as expected because last command has a variable or pipe in it......."
              break
            else
              # if no, this means the example failed
              log "Error! Script for shell${d} finished successfully without expected output in log!"
              if [[ "${VERBOSE_ERROR:-}" == "true" ]]; then
                cat "$SHELL_LOG_FILE"
              fi
              return
            fi
          fi
          subshell_finished="true"
        fi
      else
        # sleep for 1 second to burn less CPU while waiting
        sleep 1
      fi
      (( i=i+1 ))
      if [[ "${LAST_CMD}" != "${ORIG_LAST_CMD}" ]]; then
        # check if the last command was a command with a variable or pipe in it
        if [[ i -gt 300 ]]; then
          # if waited over 300 seconds and command hasn't failed but output not seen in log; assume it got started successfully
          log "Warning! Script for shell${d} running for over 300 seconds without expected output in log! Assuming everything is running as expected because last command has a variable or pipe in it......."
          break
        fi
      fi
    done

    # if last command was to start metrics UI
    if [[ "$LAST_CMD" == "metrics_reporter_ui start" ]]; then
      ## starting metrics ui.. script will exit once done so wait for it
      RET_CODE=0
      wait ${last_pid} || RET_CODE=$?
      ## starting metrics ui script exits shell command before metrics ui is fully started due to forking
      ## check to make sure it's really started
      # sleep to avoid picking up first instance of start before restart/stop occur
      sleep 1
      i=1
      # look for erlang prompt in log file to confirm metrics UI is running successfully since the command forks and returns prior to the UI being up and functional
      while [[ "$(tail -n 1 "${WALLAROO_DIR}/tmp/log/erlang.log.1")" != "iex(metrics_reporter_ui@127.0.0.1)1> " ]]; do
        sleep 1
        (( i=i+1 ))
        RET_CODE=0
        # check for exit code from script
        wait ${last_pid} || RET_CODE=$?
        if [[ "${RET_CODE}" != "0" ]]; then
          # if error and tried too many times, the example failed
          if [[ $j -gt 3 ]]; then
            log "Error! Script for shell${d} failed with ${RET_CODE}! Tried multiple times (because it is the metrics_ui) with no success!"
            if [[ "${VERBOSE_ERROR:-}" == "true" ]]; then
              cat "$SHELL_LOG_FILE"
            fi
            return
          fi
          ## else, we have a failure for metrics_ui... try it again in case it was a weird transient thing..
          # call cleanup to kill any dangling processes since nothing should be running at this point
          cleanup
          rm -f "${WALLAROO_DIR}/tmp/log/"*
          SHELL_LOG_FILE="$MY_TMP/shell${d}.log.${j}"
          ${DOCKER_PREFIX} "$MY_TMP/shell${d}.bash" > "$SHELL_LOG_FILE" 2>&1 &
          last_pid=$!
          sleep 1
          (( i=1 ))
          (( j=j+1 ))
        fi
        # wait for 15 seconds for output in log file before assuming issues with metrics ui and trying to restart it
        if [[ $i -gt 15 ]]; then
          # if timed out and tried too many times, the example failed
          if [[ $j -gt 3 ]]; then
            log "Error! Metrics reporter taking too long to start! Tried multiple times (because it is the metrics_ui) with no success!"
            if [[ "${VERBOSE_ERROR:-}" == "true" ]]; then
              cat "$SHELL_LOG_FILE"
            fi
            return
          fi
          ## we have a time out for metrics_ui... try it again in case it was a weird transient thing..
          # call cleanup to kill any dangling processes since nothing should be running at this point
          cleanup
          rm -f "${WALLAROO_DIR}/tmp/log/"*
          SHELL_LOG_FILE="$MY_TMP/shell${d}.log.${j}"
          ${DOCKER_PREFIX} "$MY_TMP/shell${d}.bash" > "$SHELL_LOG_FILE" 2>&1 &
          last_pid=$!
          sleep 1
          (( i=1 ))
          (( j=j+1 ))
        fi
      done
    fi

    # grep successul... check to make sure command didn't fail
    if ! ps -p $last_pid > /dev/null; then
      # process doesn't exist; check exit code
      # if non-zero then we have a failure
      RET_CODE=0
      wait ${last_pid} || RET_CODE=$?
      if [[ "${RET_CODE}" != "0" ]]; then
        log "Error! Script for shell${d} failed with ${RET_CODE}!"
        if [[ "${VERBOSE_ERROR:-}" == "true" ]]; then
          cat "$SHELL_LOG_FILE"
        fi
        return
      fi
    fi

    # if it's the last shell script, by convention the last shell script has shutdown commands
    if [[ "$d" -eq "($c - 1)" ]]; then
      log "Waiting for shutdown commands to finish..."
      RET_CODE=0
      # wait for shutdown commands to run
      wait ${last_pid} || RET_CODE=$?
      if [[ "${RET_CODE}" != "0" ]]; then
        log "Error! Script for shell${d} failed with ${RET_CODE}!"
        if [[ "${VERBOSE_ERROR:-}" == "true" ]]; then
          cat "$SHELL_LOG_FILE"
        fi
        return
      fi
      # log the fact that everything ran successfully for this example
      log "Everything ran successfully. Cleaning up any errant processes..."
      echo "SUCCESS" > "${RESULT_FILE}"
    fi

    my_pids="$my_pids $last_pid"
    (( d=d+1 ))
  done
  log "=================="
  log "Done with example in directory: $file_dir"
  log "$(date)"
  log "=================="
  log ""
  popd
}

# print result for a specific example
print_result() {
  # extract result info and example info
  result_file="$1"
  result_dir="$(dirname "${result_file}")"
  result_dir_parent="$(dirname "${result_dir}")"
  example_name="$(basename "${result_dir}")"
  example_type="$(basename "${result_dir_parent}")"

  # printf fixed width output to variable
  o=$(printf "%-10s| %-50s| %-7s" "${example_type}" "${example_name}" "$(cat "$result_file")")

  # log result for this example
  log "${o}"
}

# print results for all examples
print_results() {
  LOG_FILE="${TESTING_TMP}/summary.log"
  log "=============================== RESULTS ==============================="
  o=$(printf "%-10s| %-50s| %-7s" "TYPE" "EXAMPLE" "RESULT")
  log "${o}"
  log "-----------------------------------------------------------------------"
  failed_count=0
  total_count=0
  # find all result files
  # shellcheck disable=SC2044
  for result_file in $(find "${TESTING_TMP}" -name result | xargs ls -rt); do
    print_result "$result_file"
    # keep track of number failed and number total
    if [[ "$(cat "$result_file")" == "FAILURE" ]]; then
      (( failed_count = failed_count + 1 ))
    fi
    (( total_count = total_count + 1 ))
  done
  log "======================================================================="
  log ""
  log "=============================== SUMMARY ==============================="
  log "${failed_count} out of ${total_count} failed."
  log "======================================================================="

  # if number failed is greater than 0 then exit with an error code
  if [[ $failed_count -ne 0 ]]; then
    exit 1
  fi
}

# TODO: Add ability to test parts of the wallaroo book (install from source, vagrant, run an application, etc) where possible.
# iterate through all examples and run them
# shellcheck disable=SC2231
for file in "$(readlink -e "${WALLAROO_DIR}/examples")"/${LANG_TO_TEST}/${EXAMPLE_TO_TEST}/README.md; do
  # if it's the connectors example skip it
  if [[ "${file}" == *connectors* ]]; then
    continue
  fi

  # call cleanup to kill any dangling processes started by this script to ensure a clean slate
  cleanup
  parse_and_run "$file"
  # call cleanup to kill any dangling processes started by this script to ensure a clean slate
  cleanup
done

print_results
