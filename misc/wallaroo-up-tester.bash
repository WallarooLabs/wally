#!/bin/bash

set -eEuo pipefail

WALLAROO_RELEASE_TESTER_NAME=wallaroo-release-tester

# function to log output to file
log() {
  REDIRECT=" 2>&1 | tee -a $LOG_FILE"
  tmp_cmd="echo \"$WALLAROO_RELEASE_TESTER_NAME: $1\" $REDIRECT"
  eval "$tmp_cmd"
}


TEST_CUSTOM=${1:-}
ENV_TO_TEST=${2:-all}
DISTRO_TO_TEST=${3:-}

VALID_ENVS="
all
docker
vagrant
"

DOCKER_TEST=
VAGRANT_TEST=

# confirm we're running for a valid environment and set variables accordingly
if ! echo "$VALID_ENVS" | grep "^$ENV_TO_TEST\$" >/dev/null; then
  echo "Invalid env! '$ENV_TO_TEST'"
  exit 1
else
  case "$ENV_TO_TEST" in
    docker)
      DOCKER_TEST="true"
    ;;

    vagrant)
      VAGRANT_TEST="true"
    ;;

    all)
      DOCKER_TEST="true"
      VAGRANT_TEST="true"
    ;;
  esac
fi

# define realpath if it doesn't exist
command -v realpath >/dev/null 2>&1 || realpath() {
  cd "$1"; pwd -P
}

# figure out wallaroo directory, script directory and set testing temp relative to it
HERE="$(realpath "$(dirname "${0}")")"
WALLAROO_DIR="$(realpath "${HERE}/..")"
TESTING_TMP="${HERE}/logs/wallaroo-release-tester"

# If we're testing custom artifacts then build them
CUSTOM_MESSAGE=
if [[ "${TEST_CUSTOM}" == "custom" ]]; then
  CUSTOM_MESSAGE="with custom artifacts"
  pushd "${WALLAROO_DIR}"
  CUSTOM_WALLAROO_SOURCE_TGZ_URL="${WALLAROO_DIR}/wallaroo.tgz"
  CUSTOM_WALLAROO_METRICS_UI_APPIMAGE_URL="${WALLAROO_DIR}/Wallaroo_Metrics_UI-x86_64.AppImage"
  if [[ ! -e "${CUSTOM_WALLAROO_SOURCE_TGZ_URL}" ]]; then
    echo "Building wallaroo source archive for testing using custom artifacts..."
    make build-wallaroo-source-archive
  fi
  if [[ ! -e "${CUSTOM_WALLAROO_METRICS_UI_APPIMAGE_URL}" ]]; then
    echo "Building wallaroo metrics ui appimage for testing using custom artifacts..."
    make build-metrics-ui-appimage
  fi
  popd
fi

# distributions to test. format is "DOCKER_REPO VAGRANT_BOX"
declare -a DISTROS_TO_TEST=(
"debian:jessie,debian/jessie64"
"debian:stretch,debian/stretch64"
"ubuntu:trusty,ubuntu/trusty64"
"ubuntu:xenial,ubuntu/xenial64"
"ubuntu:bionic,ubuntu/bionic64"
"ubuntu:artful,ubuntu/artful64"
"centos:7,centos/7"
"fedora:27,fedora/27-cloud-base"
"fedora:28,fedora/28-cloud-base"
"amazonlinux:2,gbailey/amzn2"
"oraclelinux:7,generic/oracle7"
"debian:buster,fujimakishouten/debian-buster64"
)

# set some linux/mac specific stuff
if [[ "$(uname -s)" == "Linux" ]]; then
  SUDO_COMMAND="sudo "
  SED_ARGS=-i
else
  SUDO_COMMAND=
  SED_ARGS="-i.bak"
fi

# print result for a specific example
print_result() {
  # extract result info and example info
  result_file="$1"
  result_dir="$(dirname "${result_file}")"
  result_dir_parent="$(dirname "${result_dir}")"
  example_name="$(basename "${result_dir}")"
  example_type="$(basename "${result_dir_parent}")"

  if [[ "${example_type}" == "docker" || "${example_type}" == "vagrant" ]]; then
    log "-----------------------------------------------------------------------"
  fi

  # printf fixed width output to variable
  o=$(printf "%-10s| %-50s| %-7s" "${example_type}" "${example_name}" "$(cat "$result_file")")

  # log result for this example
  log "${o}"

  if [[ "${example_type}" == "docker" || "${example_type}" == "vagrant" ]]; then
    log "......................................................................."
  fi
}

# print results for a all examples
print_results() {
  mkdir -p "${TESTING_TMP}"
  LOG_FILE="${TESTING_TMP}/summary.log"
  log "=============================== RESULTS ==============================="
  o=$(printf "%-10s| %-50s| %-7s" "TYPE" "EXAMPLE" "RESULT")
  log "${o}"
  failed_count=0
  total_count=0
  example_failed_count=0
  example_total_count=0
  # find all result files
  # shellcheck disable=SC2044
  for result_file in $(find "${TESTING_TMP}" -maxdepth 4 -name result | xargs ls -rt); do
    print_result "$result_file"
    # keep track of number failed and number total
    (( total_count = total_count + 1 ))
    if [[ "$(cat "$result_file")" == "FAILURE" ]]; then
      (( failed_count = failed_count + 1 ))
    fi
    if [[ -e "${result_dir}/wallaroo-example-tester" ]]; then
      # shellcheck disable=SC2044
      for rf in $(find "${result_dir}/wallaroo-example-tester" -name result | xargs ls -rt); do
        print_result "$rf"
        # keep track of number failed and number total
        (( example_total_count = example_total_count + 1 ))
        if [[ "$(cat "$rf")" == "FAILURE" ]]; then
          (( example_failed_count = example_failed_count + 1 ))
        fi
      done
    fi
  done
  log "======================================================================="
  log ""
  log "=============================== SUMMARY ==============================="
  log "${failed_count} out of ${total_count} distros failed (wallaroo-up or some example)."
  log "${example_failed_count} out of ${example_total_count} examples failed."
  log "======================================================================="

  # if number failed is greater than 0 then exit with an error code
  if [[ $failed_count -ne 0 ]]; then
    exit 1
  fi
}

# set command that need to be run in vagrant/docker to run a test
# shellcheck disable=SC2010
set_commands_to_run() {
  commands_to_run="
export CUSTOM_WALLAROO_SOURCE_TGZ_URL=${CUSTOM_WALLAROO_SOURCE_TGZ_URL:-} && \
export CUSTOM_WALLAROO_METRICS_UI_APPIMAGE_URL=${CUSTOM_WALLAROO_METRICS_UI_APPIMAGE_URL:-} && \
cd '${tmp_for_run}' && \
(echo y | ${HERE}/wallaroo-up.sh -t python || exit) && \
export TMPDIR='${tmp_for_run}' && \
(~/wallaroo-tutorial/wallaroo*/misc/example-tester.bash || exit) && \
echo SUCCESS > ${tmp_for_run}/result
"
}

# run docker commands to test a specific distro
run_docker() {
  if ! docker run --rm --net=host -v /var/run/docker.sock:/var/run/docker.sock -v "${WALLAROO_DIR}":"${WALLAROO_DIR}" -w "${tmp_for_run}" --name wally-tester "${docker_distro}" sh -c "${commands_to_run}" 2>&1 | tee -a "$LOG_FILE"; then
    return
  fi
  if ! docker rmi "${docker_distro}"; then
    return
  fi
}

# run vagrant commands to test a specific distro
run_vagrant() {
  # initialize vagrant file
  if ! vagrant init "${vagrant_distro}" 2>&1 | tee -a "$LOG_FILE"; then
    return
  fi

  # edit vagrant file to add wallaroo synced folder and memory needed
  if [[ "$vagrant_distro" == "generic/oracle7" ]]; then
    sed "${SED_ARGS}" -e "s@^end@  config.vbguest.auto_update = false;  config.vm.synced_folder '${WALLAROO_DIR}', '${WALLAROO_DIR}';  config.vm.provider 'virtualbox' do |vb|    vb.memory = 4084  end  end@" Vagrantfile
  else
    sed "${SED_ARGS}" -e "s@^end@  config.vm.synced_folder '${WALLAROO_DIR}', '${WALLAROO_DIR}';  config.vm.provider 'virtualbox' do |vb|    vb.memory = 4084  end  end@" Vagrantfile
  fi

  # start vagrant box; destroy it if it doesn't start successfully
  if ! vagrant up 2>&1 | tee -a "$LOG_FILE"; then
    if ! vagrant halt 2>&1 | tee -a "$LOG_FILE"; then
      vagrant destroy -f 2>&1 | tee -a "$LOG_FILE"
      return
    fi

    if ! vagrant up 2>&1 | tee -a "$LOG_FILE"; then
      vagrant destroy -f 2>&1 | tee -a "$LOG_FILE"
      return
    fi
  fi

  # ssh into vagrant and run the command to test everything; destroy the vagrant box if there's an error
  if ! vagrant ssh -c "${commands_to_run}" 2>&1 | tee -a "$LOG_FILE"; then
    vagrant destroy -f 2>&1 | tee -a "$LOG_FILE"
    return
  fi

  # destroy the vagrant box
  if ! vagrant destroy -f 2>&1 | tee -a "$LOG_FILE"; then
    return
  fi
}

# iterate through all distros to test
for distro in "${DISTROS_TO_TEST[@]}"
do
  # if it's not a distro we're testing then skip it
  if [[ "${distro}" != *"${DISTRO_TO_TEST}"* ]]; then
    continue
  fi

  # extract out the docker/vagrant names for this distro
  IFS="," read -r -a a <<< "$distro"
  docker_distro="${a[0]}"
  vagrant_distro="${a[1]}"

  # if we're testing docker
  if [[ "${DOCKER_TEST}" == "true" ]]; then
    # set and create tmp directory for this test run
    tmp_for_run="${TESTING_TMP}/docker/${docker_distro/:/-}"
    mkdir -p "${tmp_for_run}"
    ${SUDO_COMMAND} rm -rf "${tmp_for_run}/"*
    pushd "${tmp_for_run}"
    LOG_FILE="${tmp_for_run}/docker.log"

    log "=================="
    log "Running docker wallaroo-up release test for: $docker_distro $CUSTOM_MESSAGE"
    log "$(date)"
    log "=================="
    log ""

    # set result to failure and commands to run
    echo FAILURE > "${tmp_for_run}/result"
    set_commands_to_run

    # run commands; will change result to success if everything passes
    run_docker

    log "=================="
    log "Done running docker wallaroo-up release test for: $docker_distro $CUSTOM_MESSAGE"
    log "$(date)"
    log "=================="
    log ""
    popd
  fi

  # if we're testing vagrant
  if [[ "${VAGRANT_TEST}" == "true" ]]; then
    # set and create tmp directory for this test run
    echo "vagrant: $vagrant_distro"
    tmp_for_run="${TESTING_TMP}/vagrant/${vagrant_distro/\//-}"
    mkdir -p "${tmp_for_run}"
    ${SUDO_COMMAND} rm -rf "${tmp_for_run}/"*
    pushd "${tmp_for_run}"
    LOG_FILE="${tmp_for_run}/vagrant.log"

    log "=================="
    log "Running vagrant wallaroo-up release test for: $vagrant_distro $CUSTOM_MESSAGE"
    log "$(date)"
    log "=================="
    log ""

    # set result to failure and commands to run
    echo FAILURE > "${tmp_for_run}/result"
    set_commands_to_run

    # run commands; will change result to success if everything passes
    run_vagrant

    log "=================="
    log "Done running vagrant wallaroo-up release test for: $vagrant_distro $CUSTOM_MESSAGE"
    log "$(date)"
    log "=================="
    log ""
    popd
  fi
done

print_results

# TODO: Add ability to test parts of the wallaroo book (install from source, vagrant, run an application, etc) where possible. (NOTE: this requires doing a search/replace of the book variables first to get good/working instructions from the md files)
# TODO: add ability to test wallaroo-up (both go and python)(for all distributions supported?)
## simulate steps from wallaroo-up-setup then run an application then run example tester then kill vagrant box to clean up
# TODO: add ability to test wallaroo vagrant box (both go and python)
## install prereqs for env (vagrant/virtualbox) then simulate steps from vagrant-setup then run an application then run example tester then kill vagrant box to clean up
# TODO: add ability to test wallaroo install from source (both go and python and all ubuntu versions officially supported)
## simulate steps from install from source then run an application then run example tester then delete any temp files to clean up
## this could potentially allow for adding in instructions for other distros if we want since they can be tested via automation
# TODO: add ability to test wallaroo docker container (both go and python)
## install prereqs for env (docker) then simulate steps from docker-setup then run an application then run example tester then delete any temp files to clean up
# TODO: add ability to test wallaroo vagrant/docker in windows environments? (both go and python) (Vagrant?? or AWS?? or both??)
## install prereqs for env (vagrant/virtualbox) then simulate steps from vagrant-setup then run an application then run example tester then kill vagrant box to clean up
## install prereqs for env (docker) then simulate steps from docker-setup then run an application then run example tester then delete any temp files to clean up
# TODO: add support for "data science"/similar type linux distros in wally up and here
# TODO: AWS based testing
## with RHEL 7 instance in addition to all the others (will require support in wally up)
## ideally with parallelism (for quicker turnaround)
# TODO: rename "release-tester" to "wallaroo-up-tester"
# TODO: create script of shared functions to source from other scripts to avoid copy/paste (NOTE: wallaroo-up must remain fully self contained)
# TODO: create "book-tester" (purpose: automate following instructions from book to ensure they work)
## replace variables in book
## run various installation types for different environments + run an application for that environment + example tester + cleanup (see earlier TODOs)
# TODO: goal: single command to run wallaroo up and all examples (and possibly automated testing of other things also) (for docker, vagrant, wallaroo vagrant, wallaroo docker) with either custom files or normal released files (for release testing). This should run through everything and save all logs (wallaroo-up, example test logs, etc) and produce a report at the end of results of what passed/failed (optionally allow for exit on first failure). ideal case, someone can start and then go sleep and wake up to results to review for everything. should work on at least mac osx and linux. even better if it can work in a virtualized environment (probably wouldn't be able to run vagrant due to lack of nested virtualization but can try and record it didn't work for summary).
## after this, the release testing process would be:
### run this automated thing and confirm everything successful
### manual review of book documentation for grammar/error/etc
### manual run through for sections of book that are not automated tested
#### windows stuff manually (any way to automate this? maybe via vagrant??)
#### running a wallaroo application pages
#### etc
## automated release testing thing should be run before cutting a release branch (to ensure things are in a good state prior to cutting the branch)
## before release promotion (to ensure any changes made on the release branch are in a good state)
## after release promotion but before announcement (to ensure the merge process into the release branch left everything in a good state)
####### automated testing can take forever due to how long each variation takes (wallaroo-up/example testing/etc)
