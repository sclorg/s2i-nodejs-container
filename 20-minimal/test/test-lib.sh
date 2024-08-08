# shellcheck shell=bash
#
# Test a container image.
#
# Always use sourced from a specific container testfile
#

# Container CI tests
# abbreviated as "ct"

# run ct_init before starting the actual testsuite

# shellcheck disable=SC2148
if [ -z "${sourced_test_lib:-}" ]; then
  sourced_test_lib=1
else
  return 0
fi

LINE="=============================================="

# may be redefined in the specific container testfile
EXPECTED_EXIT_CODE=0

# define UNSTABLE_TESTS if not already defined, as this variable
# is not mandatory for containers
UNSTABLE_TESTS="${UNSTABLE_TESTS:-""}"


# ct_init
# --------------------
# This function needs to be called before any container test starts
# Sets: $APP_ID_FILE_DIR - path to directory used for storing
# IDs of application images used during tests.
# Sets: $CID_FILE_DIR - path to directory containing cid_files
# Sets: $TEST_SUMMARY - string, where test results are written
# Sets: $TESTSUITE_RESULT - overall result of run testuite
function ct_init() {
  APP_ID_FILE_DIR="$(mktemp -d)"
  CID_FILE_DIR="$(mktemp -d)"
  TEST_SUMMARY=""
  TESTSUITE_RESULT=0
  ct_enable_cleanup
}

# ct_cleanup
# --------------------
# Cleans up containers used during tests. Stops and removes all containers
# referenced by cid_files in CID_FILE_DIR. Dumps logs if a container exited
# unexpectedly. Removes the cid_files and CID_FILE_DIR as well.
# Uses: $CID_FILE_DIR - path to directory containing cid_files
# Uses: $EXPECTED_EXIT_CODE - expected container exit code
# Uses: $TESTSUITE_RESULT - overall result of all tests
function ct_cleanup() {
  echo "$LINE"
  echo "Cleaning of testing containers and images started."
  echo "It may take a few seconds."
  echo "$LINE"
  ct_clean_app_images
  ct_clean_containers
}

# ct_build_image_and_parse_id
# --------------------
# Return 0 if build was successful, 1 otherwise
# Uses: $1 - path to docckerfile
# Uses: $2 - build params
# Uses: $APP_IMAGE_ID - sets the app image id value to this variable
# this should be replaced by the --iidfile parameter
# when it becames supported by all versions of podman and docker that we support
ct_build_image_and_parse_id() {
  local tmpdir
  local log_file
  local ret_val
  local dockerfile
  local command
  local pid_build
  local pid_sleep
  local sleep_time
  log_file="$(mktemp)"
  sleep_time="10m"
  [ -n "$1" ] && dockerfile="-f $1"
  command="$(echo "docker build --no-cache $dockerfile $2" | tr -d "'")"
  # running command in subshell, the subshell in background, storing pid to variable
  (
    $command > "$log_file" 2>&1
  ) & pid_build=$!
  # creating second subshell with trap function on ALRM signal
  # the subshell sleeps for 10m, then kills the first subshell
  (
    trap 'exit 0' ALRM; sleep "$sleep_time" && kill $pid_build
  ) & pid_sleep=$!
  # waiting for build subshell to finish, either with success, or killed from sleep subshell
  wait $pid_build
  ret_val=$?
  # send ALRM signal to the sleep subshell, so it exits even in case the 10mins
  # not yet passed. If the kill was successful (the wait subshell received ALRM signal)
  # then the build was not finished yet, so the return value is set to 1
  kill -s ALRM $pid_sleep 2>/dev/null || ret_val=1

  if [ $ret_val -eq 0 ]; then
    APP_IMAGE_ID="$(tail -n 1 "$log_file")"
  fi

  cat "$log_file" ; rm -r "$log_file"
  return "$ret_val"
}

# ct_container_running
# --------------------
# Return 0 if given container is in running state
# Uses: $1 - container id to check
function ct_container_running() {
  local running
  running="$(docker inspect -f '{{.State.Running}}' "$1")"
  [ "$running" = "true" ] || return 1
}

# ct_container_exists
# --------------------
# Return 0 if given container exists
# Uses: $1 - container id to check
function ct_container_exists() {
  local exists
  exists="$(docker ps -q -a -f "id=$1")"
  [ -n "$exists" ] || return 1
}

# ct_clean_app_images
# --------------------
# Cleans up application images referenced by APP_ID_FILE_DIR
# Uses: $APP_ID_FILE_DIR - path to directory containing image ID files
function ct_clean_app_images() {
  local image
  if [[ ! -d "${APP_ID_FILE_DIR:-}" ]]; then
    echo "The \$APP_ID_FILE_DIR=$APP_ID_FILE_DIR is not created. App cleaning is to be skipped."
    return 0
  fi;
  echo "Examining image ID files in \$APP_ID_FILE_DIR=$APP_ID_FILE_DIR"
  for file in "${APP_ID_FILE_DIR:?}"/*; do
    image="$(cat "$file")"
    docker inspect "$image" > /dev/null 2>&1 || continue
    containers="$(docker ps -q -a -f ancestor="$image")"
    [[ -z "$containers" ]] || docker rm -f "$containers" 2>/dev/null
    docker rmi -f "$image"
  done
  rm -fr "$APP_ID_FILE_DIR"
}

# ct_clean_containers
# --------------------
# Cleans up containers referenced by CID_FILE_DIR
# Uses: $CID_FILE_DIR - path to directory containing cid_files
function ct_clean_containers() {
  if [[ -z ${CID_FILE_DIR:-} ]]; then
    echo "The \$CID_FILE_DIR is not set. Container cleaning is to be skipped."
    return
  fi;

  echo "Examining CID files in \$CID_FILE_DIR=$CID_FILE_DIR"
  for cid_file in "$CID_FILE_DIR"/* ; do
    [ -f "$cid_file" ] || continue
    local container
    container=$(cat "$cid_file")

    ct_container_exists "$container" || continue

    echo "Stopping and removing container $container..."
    if ct_container_running "$container"; then
      docker stop "$container"
    fi

    exit_status=$(docker inspect -f '{{.State.ExitCode}}' "$container")
    if [ "$exit_status" != "$EXPECTED_EXIT_CODE" ]; then
      echo "Dumping logs for $container"
      docker logs "$container"
    fi
    docker rm -v "$container"
    rm -f "$cid_file"
  done

  rm -rf "$CID_FILE_DIR"
}

# ct_show_results
# ---------------
# Prints results of all test cases that are stored into TEST_SUMMARY variable.
# Uses: $IMAGE_NAME - name of the tested container image
# Uses: $TEST_SUMMARY - text info about test-cases
# Uses: $TESTSUITE_RESULT - overall result of all tests
function ct_show_results() {
  echo "$LINE"
  #shellcheck disable=SC2153
  echo "Tests were run for image ${IMAGE_NAME}"
  echo "$LINE"
  echo "Test cases results:"
  echo
  echo "${TEST_SUMMARY:-}"

  if [ -n "${TESTSUITE_RESULT:-}" ] ; then
    if [ "$TESTSUITE_RESULT" -eq 0 ] ; then
      # shellcheck disable=SC2153
      echo "Tests for ${IMAGE_NAME} succeeded."
    else
      # shellcheck disable=SC2153
      echo "Tests for ${IMAGE_NAME} failed."
    fi
  fi
}

# ct_enable_cleanup
# --------------------
# Enables automatic container cleanup after tests.
function ct_enable_cleanup() {
  trap ct_trap_on_exit EXIT
  trap ct_trap_on_sigint SIGINT
}

# ct_trap_on_exit
# --------------------
function ct_trap_on_exit() {
  local exit_code=$?
  [ "$exit_code" -eq 130 ] && return # we do not want to catch SIGINT here
  # We should not really care about what the script returns
  # as the tests are constructed the way they never exit the shell.
  # The check is added just to be sure that we catch some not expected behavior
  # if any is added in the future.
  echo "Tests finished with EXIT=$exit_code"
  [ $exit_code -eq 0 ] && exit_code="${TESTSUITE_RESULT:-0}"
  [ -n "${DEBUG:-}" ] || ct_show_resources
  ct_cleanup
  ct_show_results
  exit "$exit_code"
}

# ct_trap_on_sigint
# --------------------
function ct_trap_on_sigint() {
  echo "Tests were stopped by SIGINT signal"
  ct_cleanup
  ct_show_results
  exit 130
}

# ct_pull_image
# -------------
# Function pull an image before tests execution
# Argument: image_name - string containing the public name of the image to pull
# Argument: exit - in case "true" is defined and pull failed, then script has to exit with 1 and no tests are executed
# Argument: loops - how many times to pull image in case of failure
# Function returns either 0 in case of pull was successful
# Or the test suite exit with 1 in case of pull error
function ct_pull_image() {
  local image_name="$1"; [[ $# -gt 0 ]] && shift
  local exit_variable=${1:-"false"}; [[ $# -gt 0 ]] && shift
  local loops=${1:-10}
  local loop=0

  # Let's try to pull image.
  echo "-> Pulling image $image_name ..."
  # Sometimes in Fedora case it fails with HTTP 50X
  # Check if the image is available locally and try to pull it if it is not
  if [[ "$(docker images -q "$image_name" 2>/dev/null)" != "" ]]; then
    echo "The image $image_name is already pulled."
    return 0
  fi

  # Try pulling the image to see if it is accessible
  # WORKAROUND: Since Fedora registry sometimes fails randomly, let's try it more times
  while ! docker pull "$image_name"; do
    ((loop++)) || :
    echo "Pulling image $image_name failed."
    if [ "$loop" -gt "$loops" ]; then
      echo "Pulling of image $image_name failed $loops times in a row. Giving up."
      echo "!!! ERROR with pulling image $image_name !!!!"
      # shellcheck disable=SC2268
      if [[ x"$exit_variable" == x"false" ]]; then
        return 1
      else
        exit 1
      fi
    fi
    echo "Let's wait $((loop*5)) seconds and try again."
    sleep "$((loop*5))"
  done
}


# ct_check_envs_set env_filter check_envs loop_envs [env_format]
# --------------------
# Compares values from one list of environment variable definitions against such list,
# checking if the values are present and have a specific format.
# Argument: env_filter - optional string passed to grep used for
#   choosing which variables to filter out in env var lists.
# Argument: check_envs - list of env var definitions to check values against
# Argument: loop_envs - list of env var definitions to check values for
# Argument: env_format (optional) - format string for bash substring deletion used
#   for checking whether the value is contained in check_envs.
#   Defaults to: "*VALUE*", VALUE string gets replaced by actual value from loop_envs
function ct_check_envs_set {
  local env_filter check_envs env_format
  env_filter=$1; shift
  check_envs=$1; shift
  loop_envs=$1; shift
  env_format=${1:-"*VALUE*"}
  while read -r variable; do
    [ -z "$variable" ] && continue
    var_name=$(echo "$variable" | awk -F= '{ print $1 }')
    stripped=$(echo "$variable" | awk -F= '{ print $2 }')
    filtered_envs=$(echo "$check_envs" | grep "^$var_name=")
    [ -z "$filtered_envs" ] && { echo "$var_name not found during \` docker exec\`"; return 1; }
    old_IFS=$IFS
    # For each such variable compare its content with the `docker exec` result, use `:` as delimiter
    IFS=:
    for value in $stripped; do
        # If the falue checked does not go through env_filter we do not care about it
        echo "$value" | grep -q "$env_filter" || continue
        # shellcheck disable=SC2295
        if [ -n "${filtered_envs##${env_format//VALUE/$value}}" ]; then
            echo " Value $value is missing from variable $var_name"
            echo "$filtered_envs"
            IFS=$old_IFS
            return 1
        fi
    done
    IFS=$old_IFS
  done <<< "$(echo "$loop_envs" | grep "$env_filter" | grep -v "^PWD=")"
}

# ct_get_cid [name]
# --------------------
# Prints container id from cid_file based on the name of the file.
# Argument: name - name of cid_file where the container id will be stored
# Uses: $CID_FILE_DIR - path to directory containing cid_files
function ct_get_cid() {
  local name="$1" ; shift || return 1
  cat "$CID_FILE_DIR/$name"
}

# ct_get_cip [id]
# --------------------
# Prints container ip address based on the container id.
# Argument: id - container id
function ct_get_cip() {
  local id="$1" ; shift
  docker inspect --format='{{.NetworkSettings.IPAddress}}' "$(ct_get_cid "$id")"
}

# ct_wait_for_cid [cid_file]
# --------------------
# Holds the execution until the cid_file is created. Usually run after container
# creation.
# Argument: cid_file - name of the cid_file that should be created
function ct_wait_for_cid() {
  local cid_file=$1
  local max_attempts=10
  local sleep_time=1
  local attempt=1
  local result=1
  while [ $attempt -le $max_attempts ]; do
    [ -f "$cid_file" ] && [ -s "$cid_file" ] && return 0
    echo "Waiting for container start... $attempt"
    attempt=$(( attempt + 1 ))
    sleep $sleep_time
  done
  return 1
}

# ct_assert_container_creation_fails [container_args]
# --------------------
# The invocation of docker run should fail based on invalid container_args
# passed to the function. Returns 0 when container fails to start properly.
# Argument: container_args - all arguments are passed directly to dokcer run
# Uses: $CID_FILE_DIR - path to directory containing cid_files
function ct_assert_container_creation_fails() {
  local ret=0
  local max_attempts=10
  local attempt=1
  local cid_file=assert
  local old_container_args="${CONTAINER_ARGS-}"
  # we really work with CONTAINER_ARGS as with a string
  # shellcheck disable=SC2124
  CONTAINER_ARGS="$@"
  if ct_create_container "$cid_file" ; then
    local cid
    cid=$(ct_get_cid "$cid_file")

    while [ "$(docker inspect -f '{{.State.Running}}' "$cid")" == "true" ] ; do
      sleep 2
      attempt=$(( attempt + 1 ))
      if [ "$attempt" -gt "$max_attempts" ]; then
        docker stop "$cid"
        ret=1
        break
      fi
    done
    exit_status=$(docker inspect -f '{{.State.ExitCode}}' "$cid")
    if [ "$exit_status" == "0" ]; then
      ret=1
    fi
    docker rm -v "$cid"
    rm "$CID_FILE_DIR/$cid_file"
  fi
  [ -n "$old_container_args" ] && CONTAINER_ARGS="$old_container_args"
  return "$ret"
}

# ct_create_container [name, command]
# --------------------
# Creates a container using the IMAGE_NAME and CONTAINER_ARGS variables. Also
# stores the container id to a cid_file located in the CID_FILE_DIR, and waits
# for the creation of the file.
# Argument: name - name of cid_file where the container id will be stored
# Argument: command - optional command to be executed in the container
# Uses: $CID_FILE_DIR - path to directory containing cid_files
# Uses: $CONTAINER_ARGS - optional arguments passed directly to docker run
# Uses: $IMAGE_NAME - name of the image being tested
function ct_create_container() {
  local cid_file="$CID_FILE_DIR/$1" ; shift
  # create container with a cidfile in a directory for cleanup
  # shellcheck disable=SC2086,SC2153
  docker run --cidfile="$cid_file" -d ${CONTAINER_ARGS:-} "$IMAGE_NAME" "$@"
  ct_wait_for_cid "$cid_file" || return 1
  : "Created container $(cat "$cid_file")"
}

# ct_scl_usage_old [name, command, expected]
# --------------------
# Tests three ways of running the SCL, by looking for an expected string
# in the output of the command
# Argument: name - name of cid_file where the container id will be stored
# Argument: command - executed inside the container
# Argument: expected - string that is expected to be in the command output
# Uses: $CID_FILE_DIR - path to directory containing cid_files
# Uses: $IMAGE_NAME - name of the image being tested
function ct_scl_usage_old() {
  local name="$1"
  local command="$2"
  local expected="$3"
  local out=""
  : "  Testing the image SCL enable"
  out=$(docker run --rm "${IMAGE_NAME}" /bin/bash -c "${command}")
  if ! echo "${out}" | grep -q "${expected}"; then
    echo "ERROR[/bin/bash -c \"${command}\"] Expected '${expected}', got '${out}'" >&2
    return 1
  fi
  out=$(docker exec "$(ct_get_cid "$name")" /bin/bash -c "${command}" 2>&1)
  if ! echo "${out}" | grep -q "${expected}"; then
    echo "ERROR[exec /bin/bash -c \"${command}\"] Expected '${expected}', got '${out}'" >&2
    return 1
  fi
  out=$(docker exec "$(ct_get_cid "$name")" /bin/sh -ic "${command}" 2>&1)
  if ! echo "${out}" | grep -q "${expected}"; then
    echo "ERROR[exec /bin/sh -ic \"${command}\"] Expected '${expected}', got '${out}'" >&2
    return 1
  fi
}

# ct_doc_content_old [strings]
# --------------------
# Looks for occurence of stirngs in the documentation files and checks
# the format of the files. Files examined: help.1
# Argument: strings - strings expected to appear in the documentation
# Uses: $IMAGE_NAME - name of the image being tested
function ct_doc_content_old() {
  local tmpdir
  tmpdir=$(mktemp -d)
  local f
  : "  Testing documentation in the container image"
  # Extract the help files from the container
  # shellcheck disable=SC2043
  for f in help.1 ; do
    docker run --rm "${IMAGE_NAME}" /bin/bash -c "cat /${f}" >"${tmpdir}/$(basename "${f}")"
    # Check whether the files contain some important information
    for term in "$@" ; do
      if ! grep -E -q -e "${term}" "${tmpdir}/$(basename "${f}")" ; then
        echo "ERROR: File /${f} does not include '${term}'." >&2
        return 1
      fi
    done
    # Check whether the files use the correct format
    for term in TH PP SH ; do
      if ! grep -q "^\.${term}" "${tmpdir}/help.1" ; then
        echo "ERROR: /help.1 is probably not in troff or groff format, since '${term}' is missing." >&2
        return 1
      fi
    done
  done
  : "  Success!"
}

# full_ca_file_path
# Return string for full path to CA file
function full_ca_file_path()
{
  echo "/etc/pki/ca-trust/source/anchors/RH-IT-Root-CA.crt"
}
# ct_mount_ca_file
# ------------------
# Check if /etc/pki/certs/RH-IT-Root-CA.crt file exists
# return mount string for containers or empty string
function ct_mount_ca_file()
{
  # mount CA file only if NPM_REGISTRY variable is present.
  local mount_parameter=""
  if [ -n "$NPM_REGISTRY" ] && [ -f "$(full_ca_file_path)" ]; then
    mount_parameter="-v $(full_ca_file_path):$(full_ca_file_path):Z"
  fi
  echo "$mount_parameter"
}

# ct_build_s2i_npm_variables URL_TO_NPM_JS_SERVER
# ------------------------------------------
# Function returns -e NPM_MIRROR and -v MOUNT_POINT_FOR_CAFILE
# or empty string
function ct_build_s2i_npm_variables()
{
  npm_variables=""
  if [ -n "$NPM_REGISTRY" ] && [ -f "$(full_ca_file_path)" ]; then
    npm_variables="-e NPM_MIRROR=$NPM_REGISTRY $(ct_mount_ca_file)"
  fi
  echo "$npm_variables"
}

# ct_npm_works
# --------------------
# Checks existance of the npm tool and runs it.
function ct_npm_works() {
  local tmpdir
  local cid_file
  tmpdir=$(mktemp -d)
  : "  Testing npm in the container image"
  cid_file="$(mktemp --dry-run --tmpdir="${CID_FILE_DIR}")"
  if ! docker run --rm "${IMAGE_NAME}" /bin/bash -c "npm --version" >"${tmpdir}/version" ; then
    echo "ERROR: 'npm --version' does not work inside the image ${IMAGE_NAME}." >&2
    return 1
  fi

  # shellcheck disable=SC2046
  docker run -d $(ct_mount_ca_file) --rm --cidfile="$cid_file" "${IMAGE_NAME}-testapp"

  # Wait for the container to write it's CID file
  ct_wait_for_cid "$cid_file" || return 1

  if ! docker exec "$(cat "$cid_file")" /bin/bash -c "npm --verbose install jquery && test -f node_modules/jquery/src/jquery.js" >"${tmpdir}/jquery" 2>&1 ; then
    echo "ERROR: npm could not install jquery inside the image ${IMAGE_NAME}." >&2
    cat "${tmpdir}/jquery"
    return 1
  fi

  if [ -n "$NPM_REGISTRY" ] && [ -f "$(full_ca_file_path)" ]; then
    if ! grep -qo "$NPM_REGISTRY" "${tmpdir}/jquery"; then
        echo "ERROR: Internal repository is NOT set. Even it is requested."
        return 1
    fi
  fi

  if [ -f "$cid_file" ]; then
      docker stop "$(cat "$cid_file")"
  fi
  : "  Success!"
}

# ct_binary_found_from_df binary [path]
# --------------------
# Checks if a binary can be found in PATH during Dockerfile build
# Argument: binary - name of the binary to test accessibility for
# Argument: path - optional path in which the binary should reside in
#                  /opt/rh by default
function ct_binary_found_from_df() {
  local tmpdir
  local id_file
  local binary=$1; shift
  local binary_path=${1:-"^/opt/rh"}
  tmpdir=$(mktemp -d)
  : "  Testing $binary in build from Dockerfile"

  # Create Dockerfile that looks for the binary
  cat <<EOF >"$tmpdir/Dockerfile"
FROM $IMAGE_NAME
RUN command -v $binary | grep "$binary_path"
EOF
  # Build an image, looking for expected path in the output
  ct_build_image_and_parse_id "$tmpdir/Dockerfile" "$tmpdir"
  #shellcheck disable=SC2181
  if [ $? -ne 0 ]; then
    echo "  ERROR: Failed to find $binary in \$PATH!" >&2
    return 1
  fi
  id_file="${APP_ID_FILE_DIR:?}"/"$RANDOM"
  echo "$APP_IMAGE_ID" > "$id_file"
}

# ct_check_exec_env_vars [env_filter]
# --------------------
# Checks if all relevant environment variables from `docker run`
# can be found in `docker exec` as well.
# Argument: env_filter - optional string passed to grep used for
#   choosing which variables to check in the test case.
#   Defaults to X_SCLS and variables containing /opt/app-root, /opt/rh
# Uses: $CID_FILE_DIR - path to directory containing cid_files
# Uses: $IMAGE_NAME - name of the image being tested
function ct_check_exec_env_vars() {
  local tmpdir exec_envs cid old_IFS env_filter
  local var_name stripped filtered_envs run_envs
  env_filter=${1:-"^X_SCLS=\|/opt/rh\|/opt/app-root"}
  tmpdir=$(mktemp -d)
  CID_FILE_DIR=${CID_FILE_DIR:-$(mktemp -d)}
  # Get environment variables from `docker run`
  run_envs=$(docker run --rm "$IMAGE_NAME" /bin/bash -c "env")
  # Get environment variables from `docker exec`
  ct_create_container "test_exec_envs" bash -c "sleep 1000" >/dev/null
  cid=$(ct_get_cid "test_exec_envs")
  exec_envs=$(docker exec "$cid" env)
  # Filter out variables we are not interested in
  # Always check X_SCLS, ignore PWD
  # Check variables from `docker run` that have alternative paths inside (/opt/rh, /opt/app-root)
  ct_check_envs_set "$env_filter" "$exec_envs" "$run_envs" "*VALUE*" || return 1
  echo " All values present in \`docker exec\`"
  return 0
}

# ct_check_scl_enable_vars [env_filter]
# --------------------
# Checks if all relevant environment variables from `docker run`
# are set twice after a second call of `scl enable $SCLS`.
# Argument: env_filter - optional string passed to grep used for
#   choosing which variables to check in the test case.
#   Defaults to paths containing enabled SCLS in the image
# Uses: $IMAGE_NAME - name of the image being tested
function ct_check_scl_enable_vars() {
  local tmpdir exec_envs cid old_IFS env_filter enabled_scls
  local var_name stripped filtered_envs loop_envs
  env_filter=$1
  tmpdir=$(mktemp -d)
  enabled_scls=$(docker run --rm "$IMAGE_NAME" /bin/bash -c "echo \$X_SCLS")
  if [ -z "$env_filter" ]; then
    for scl in $enabled_scls; do
      [ -z "$env_filter" ] && env_filter="/$scl" && continue
      # env_filter not empty, append to the existing list
      env_filter="$env_filter|/$scl"
    done
  fi
  # Get environment variables from `docker run`
  loop_envs=$(docker run --rm "$IMAGE_NAME" /bin/bash -c "env")
  run_envs=$(docker run  --rm "$IMAGE_NAME" /bin/bash -c "X_SCLS= scl enable $enabled_scls env")
  # Check if the values are set twice in the second set of envs
  ct_check_envs_set "$env_filter" "$run_envs" "$loop_envs" "*VALUE*VALUE*" || return 1
  echo " All scl_enable values present"
  return 0
}

# ct_path_append PATH_VARNAME DIRECTORY
# -------------------------------------
# Append DIRECTORY to VARIABLE of name PATH_VARNAME, the VARIABLE must consist
# of colon-separated list of directories.
ct_path_append ()
{
    if eval "test -n \"\${$1-}\""; then
        eval "$1=\$2:\$$1"
    else
        eval "$1=\$2"
    fi
}


# ct_path_foreach PATH ACTION [ARGS ...]
# --------------------------------------
# For each DIR in PATH execute ACTION (path is colon separated list of
# directories).  The particular calls to ACTION will look like
# '$ ACTION directory [ARGS ...]'
ct_path_foreach ()
{
    local dir dirlist action save_IFS
    save_IFS=$IFS
    IFS=:
    dirlist=$1
    action=$2
    shift 2
    for dir in $dirlist; do "$action" "$dir" "$@" ; done
    IFS=$save_IFS
}


# ct_gen_self_signed_cert_pem
# ---------------------------
# Generates a self-signed PEM certificate pair into specified directory.
# Argument: output_dir - output directory path
# Argument: base_name - base name of the certificate files
# Resulted files will be those:
#   <output_dir>/<base_name>-cert-selfsigned.pem -- public PEM cert
#   <output_dir>/<base_name>-key.pem -- PEM private key
ct_gen_self_signed_cert_pem() {
  local output_dir=$1 ; shift
  local base_name=$1 ; shift
  mkdir -p "${output_dir}"
  openssl req -newkey rsa:2048 -nodes -keyout "${output_dir}"/"${base_name}"-key.pem -subj '/C=GB/ST=Berkshire/L=Newbury/O=My Server Company' > "${base_name}"-req.pem
  openssl req -new -x509 -nodes -key "${output_dir}"/"${base_name}"-key.pem -batch > "${output_dir}"/"${base_name}"-cert-selfsigned.pem
}

# ct_obtain_input FILE|DIR|URL
# --------------------
# Either copies a file or a directory to a tmp location for local copies, or
# downloads the file from remote location.
# Resulted file path is printed, so it can be later used by calling function.
# Arguments: input - local file, directory or remote URL
function ct_obtain_input() {
  local input=$1
  local extension="${input##*.}"

  # Try to use same extension for the temporary file if possible
  [[ "${extension}" =~ ^[a-z0-9]*$ ]] && extension=".${extension}" || extension=""

  local output
  output=$(mktemp "/var/tmp/test-input-XXXXXX$extension")
  if [ -f "${input}" ] ; then
    cp -f "${input}" "${output}"
  elif [ -d "${input}" ] ; then
    rm -f "${output}"
    cp -r -LH "${input}" "${output}"
  elif echo "${input}" | grep -qe '^http\(s\)\?://' ; then
    curl "${input}" > "${output}"
  else
    echo "ERROR: file type not known: ${input}" >&2
    return 1
  fi
  echo "${output}"
}

# ct_test_response
# ----------------
# Perform GET request to the application container, checks output with
# a reg-exp and HTTP response code.
# Argument: url - request URL path
# Argument: expected_code - expected HTTP response code
# Argument: body_regexp - PCRE regular expression that must match the response body
# Argument: max_attempts - Optional number of attempts (default: 20), three seconds sleep between
# Argument: ignore_error_attempts - Optional number of attempts when we ignore error output (default: 10)
ct_test_response() {
  local url="$1"
  local expected_code="$2"
  local body_regexp="$3"
  local max_attempts=${4:-20}
  local ignore_error_attempts=${5:-10}

  echo "  Testing the HTTP(S) response for <${url}>"
  local sleep_time=3
  local attempt=1
  local result=1
  local status
  local response_code
  local response_file
  response_file=$(mktemp /tmp/ct_test_response_XXXXXX)
  while [ "${attempt}" -le "${max_attempts}" ]; do
    echo "Trying to connect ... ${attempt}"
    curl --connect-timeout 10 -s -w '%{http_code}' "${url}" >"${response_file}" && status=0 || status=1
    if [ "${status}" -eq 0 ]; then
      response_code=$(tail -c 3 "${response_file}")
      if [ "${response_code}" -eq "${expected_code}" ]; then
        result=0
      fi
      grep -qP -e "${body_regexp}" "${response_file}" || result=1;
      # Some services return 40x code until they are ready, so let's give them
      # some chance and not end with failure right away
      # Do not wait if we already have expected outcome though
      if [ "${result}" -eq 0 ] || [ "${attempt}" -gt "${ignore_error_attempts}" ] || [ "${attempt}" -eq "${max_attempts}" ] ; then
        break
      fi
    fi
    attempt=$(( attempt + 1 ))
    sleep "${sleep_time}"
  done
  rm -f "${response_file}"
  return "${result}"
}

# ct_registry_from_os OS
# ----------------
# Transform operating system string [os] into registry url
# Argument: OS - string containing the os version
ct_registry_from_os() {
  local registry=""
  case $1 in
    rhel*)
        registry=registry.redhat.io
        ;;
    *)
        registry=quay.io
        ;;
    esac
  echo "$registry"
}

 # ct_get_public_image_name OS BASE_IMAGE_NAME VERSION
# ----------------
# Transform the arguments into public image name
# Argument: OS - string containing the os version
# Argument: BASE_IMAGE_NAME - string containing the base name of the image as defined in the Makefile
# Argument: VERSION - string containing the version of the image as defined in the Makefile
ct_get_public_image_name() {
  local os=$1; shift
  local base_image_name=$1; shift
  local version=$1; shift

  local public_image_name
  local registry

  registry=$(ct_registry_from_os "$os")
  if [ "$os" == "rhel8" ]; then
    public_image_name=$registry/rhel8/$base_image_name-${version//./}
  elif [ "$os" == "rhel9" ]; then
    public_image_name=$registry/rhel9/$base_image_name-${version//./}
  elif [ "$os" == "c9s" ]; then
    public_image_name=$registry/sclorg/$base_image_name-${version//./}-c9s
  elif [ "$os" == "c10s" ]; then
    public_image_name=$registry/sclorg/$base_image_name-${version//./}-c10s
  fi

  echo "$public_image_name"
}

# ct_assert_cmd_success CMD
# ----------------
# Evaluates [cmd] and fails if it does not succeed.
# Argument: CMD - Command to be run
function ct_assert_cmd_success() {
  echo "Checking '$*' for success ..."
  # shellcheck disable=SC2294
  if ! eval "$@" &>/dev/null; then
    echo " FAIL"
    return 1
  fi
  echo " PASS"
  return 0
}

# ct_assert_cmd_failure CMD
# ----------------
# Evaluates [cmd] and fails if it succeeds.
# Argument: CMD - Command to be run
function ct_assert_cmd_failure() {
  echo "Checking '$*' for failure ..."
  # shellcheck disable=SC2294
  if eval "$@" &>/dev/null; then
    echo " FAIL"
    return 1
  fi
  echo " PASS"
  return 0
}


# ct_random_string [LENGTH=10]
# ----------------------------
# Generate pseudorandom alphanumeric string of LENGTH bytes, the
# default length is 10.  The string is printed on stdout.
ct_random_string()
(
   export LC_ALL=C
   dd if=/dev/urandom count=1 bs=10k 2>/dev/null \
       | tr -dc 'a-z0-9' \
       | fold -w "${1-10}" \
       | head -n 1
)

# ct_s2i_usage IMG_NAME [S2I_ARGS]
# ----------------------------
# Create a container and run the usage script inside
# Argument: IMG_NAME - name of the image to be used for the container run
# Argument: S2I_ARGS - Additional list of source-to-image arguments, currently unused.
ct_s2i_usage()
{
    local img_name=$1; shift
    local s2i_args="$*";
    local usage_command="/usr/libexec/s2i/usage"
    docker run --rm "$img_name" bash -c "$usage_command"
}

# ct_s2i_build_as_df APP_PATH SRC_IMAGE DST_IMAGE [S2I_ARGS]
# ----------------------------
# Create a new s2i app image from local sources in a similar way as source-to-image would have used.
# This function is wrapper for ct_s2i_build_as_df_build_args in case user do not want to add build args
# This function is used in all https://github.com/sclorg/*-container test cases and we do not
# want to break functionality
# Argument: APP_PATH - local path to the app sources to be used in the test
# Argument: SRC_IMAGE - image to be used as a base for the s2i build
# Argument: DST_IMAGE - image name to be used during the tagging of the s2i build result
# Argument: S2I_ARGS - Additional list of source-to-image arguments.
#                      Only used to check for pull-policy=never and environment variable definitions.
ct_s2i_build_as_df()
{
    local app_path=$1; shift
    local src_image=$1; shift
    local dst_image=$1; shift
    local s2i_args="$*";

    ct_s2i_build_as_df_build_args "$app_path" "$src_image" "$dst_image" "" "$s2i_args"
}

# ct_s2i_build_as_df_build_args APP_PATH SRC_IMAGE DST_IMAGE BUILD_ARGS [S2I_ARGS]
# ----------------------------
# Create a new s2i app image from local sources in a similar way as source-to-image would have used.
# Argument: APP_PATH - local path to the app sources to be used in the test
# Argument: SRC_IMAGE - image to be used as a base for the s2i build
# Argument: DST_IMAGE - image name to be used during the tagging of the s2i build result
# Argument: BUILD_ARGS - Build arguments to be used in the s2i build
# Argument: S2I_ARGS - Additional list of source-to-image arguments.
#                      Only used to check for pull-policy=never and environment variable definitions.
ct_s2i_build_as_df_build_args()
{
    local app_path=$1; shift
    local src_image=$1; shift
    local dst_image=$1; shift
    local build_args=$1; shift
    local s2i_args="$*";
    local local_app=upload/src/
    local local_scripts=upload/scripts/
    local user_id=
    local df_name=
    local tmpdir=
    local incremental=false
    local mount_options=()
    local id_file

    # Run the entire thing inside a subshell so that we do not leak shell options outside of the function
    (
    # FIXME: removed temporarily, need proper fixing
    # Error out if any part of the build fails
    # set -e

    # Use /tmp to not pollute cwd
    tmpdir=$(mktemp -d)
    df_name=$(mktemp -p "$tmpdir" Dockerfile.XXXX)
    cd "$tmpdir" || return 1
    # Check if the image is available locally and try to pull it if it is not
    docker images "$src_image" &>/dev/null || echo "$s2i_args" | grep -q "pull-policy=never" || docker pull "$src_image"
    user=$(docker inspect -f "{{.Config.User}}" "$src_image")
    # Default to root if no user is set by the image
    user=${user:-0}
    # run the user through the image in case it is non-numeric or does not exist
    if ! user_id=$(ct_get_uid_from_image "$user" "$src_image"); then
        echo "Terminating s2i build."
        return 1
    fi

    echo "$s2i_args" | grep -q "\--incremental" && incremental=true
    if $incremental; then
        inc_tmp=$(mktemp -d --tmpdir incremental.XXXX)
        setfacl -m "u:$user_id:rwx" "$inc_tmp"
        # Check if the image exists, build should fail (for testing use case) if it does not
        docker images "$dst_image" &>/dev/null || (echo "Image $dst_image not found."; false)
        # Run the original image with a mounted in volume and get the artifacts out of it
        cmd="if [ -s /usr/libexec/s2i/save-artifacts ]; then /usr/libexec/s2i/save-artifacts > \"$inc_tmp/artifacts.tar\"; else touch \"$inc_tmp/artifacts.tar\"; fi"
        docker run --rm -v "$inc_tmp:$inc_tmp:Z" "$dst_image" bash -c "$cmd"
        # Move the created content into the $tmpdir for the build to pick it up
        mv "$inc_tmp/artifacts.tar" "$tmpdir/"
    fi
    # Strip file:// from APP_PATH and copy its contents into current context
    mkdir -p "$local_app"
    cp -r "${app_path/file:\/\//}/." "$local_app"
    [ -d "$local_app/.s2i/bin/" ] && mv "$local_app/.s2i/bin" "$local_scripts"
    # Create a Dockerfile named df_name and fill it with proper content
    #FIXME: Some commands could be combined into a single layer but not sure if worth the trouble for testing purposes
    cat <<EOF >"$df_name"
FROM $src_image
LABEL "io.openshift.s2i.build.image"="$src_image" \\
      "io.openshift.s2i.build.source-location"="$app_path"
USER root
COPY $local_app /tmp/src
EOF
    [ -d "$local_scripts" ] && echo "COPY $local_scripts /tmp/scripts" >> "$df_name" &&
    echo "RUN chown -R $user_id:0 /tmp/scripts" >>"$df_name"
    echo "RUN chown -R $user_id:0 /tmp/src" >>"$df_name"
    # Check for custom environment variables inside .s2i/ folder
    if [ -e "$local_app/.s2i/environment" ]; then
        # Remove any comments and add the contents as ENV commands to the Dockerfile
        sed '/^\s*#.*$/d' "$local_app/.s2i/environment" | while read -r line; do
            echo "ENV $line" >>"$df_name"
        done
    fi
    # Filter out env var definitions from $s2i_args and create Dockerfile ENV commands out of them
    echo "$s2i_args" | grep -o -e '\(-e\|--env\)[[:space:]=]\S*=\S*' | sed -e 's/-e /ENV /' -e 's/--env[ =]/ENV /' >>"$df_name"
    # Check if CA autority is present on host and add it into Dockerfile
    [ -f "$(full_ca_file_path)" ] && echo "RUN cd /etc/pki/ca-trust/source/anchors && update-ca-trust extract" >>"$df_name"

    # Add in artifacts if doing an incremental build
    if $incremental; then
        { echo "RUN mkdir /tmp/artifacts"
          echo "ADD artifacts.tar /tmp/artifacts"
          echo "RUN chown -R $user_id:0 /tmp/artifacts" ; } >>"$df_name"
    fi

    echo "USER $user_id" >>"$df_name"
    # If exists, run the custom assemble script, else default to /usr/libexec/s2i/assemble
    if [ -x "$local_scripts/assemble" ]; then
        echo "RUN /tmp/scripts/assemble" >>"$df_name"
    else
        echo "RUN /usr/libexec/s2i/assemble" >>"$df_name"
    fi
    # If exists, set the custom run script as CMD, else default to /usr/libexec/s2i/run
    if [ -x "$local_scripts/run" ]; then
        echo "CMD /tmp/scripts/run" >>"$df_name"
    else
        echo "CMD /usr/libexec/s2i/run" >>"$df_name"
    fi

    # Check if -v parameter is present in s2i_args and add it into docker build command
    read -ra mount_options <<< "$(echo "$s2i_args" | grep -o -e '\(-v\)[[:space:]]\.*\S*' || true)"

    # Run the build and tag the result
    ct_build_image_and_parse_id "$df_name" "${mount_options[*]+${mount_options[*]}} -t $dst_image . $build_args"
    #shellcheck disable=SC2181
    if [ "$?" -ne 0 ]; then
      echo "  ERROR: Failed to to build $df_name" >&2
      return 1
    fi
    id_file="${APP_ID_FILE_DIR:?}"/"$RANDOM"
    echo "$APP_IMAGE_ID" > "$id_file"
    )
}

# ct_s2i_multistage_build APP_PATH SRC_IMAGE DST_IMAGE SEC_IMAGE [S2I_ARGS]
# ----------------------------
# Create a new s2i app image from local sources in a similar way as source-to-image would have used.
# Argument: APP_PATH - local path to the app sources to be used in the test
# Argument: SRC_IMAGE - image to be used as a base for the s2i build process
# Argument: SEC_IMAGE - image to be used as the base for the result of the build process
# Argument: DST_IMAGE - image name to be used during the tagging of the s2i build result
# Argument: S2I_ARGS - Additional list of source-to-image arguments.
#                      Only used to check for environment variable definitions.
ct_s2i_multistage_build() {

  local app_path=$1; shift
  local src_image=$1; shift
  local sec_image=$1; shift
  local dst_image=$1; shift
  local s2i_args=$*;
  local local_app="app-src"
  local user_id=
  local mount_options=()
  local id_file


  # Run the entire thing inside a subshell so that we do not leak shell options outside of the function
  (
  # FIXME: removed temporarily, need proper fixing
  # Error out if any part of the build fails
  # set -e

  user=$(docker inspect -f "{{.Config.User}}" "$src_image")
  # Default to root if no user is set by the image
  user=${user:-0}
  # run the user through the image in case it is non-numeric or does not exist
  if ! user_id=$(ct_get_uid_from_image "$user" "$src_image"); then
      echo "Terminating s2i build."
      return 1
  fi

  # Use /tmp to not pollute cwd
  tmpdir=$(mktemp -d)
  df_name=$(mktemp -p "$tmpdir" Dockerfile.XXXX)
  cd "$tmpdir" || return 1

  # If the path exists on the local host, copy it into the directory for the build
  # Otherwise handle it as a link to a git repository
  if [ -e "${app_path/file:\/\//}/." ] ; then
    mkdir -p "$local_app"
    # Strip file:// from APP_PATH and copy its contents into current context
    cp -r "${app_path/file:\/\//}/." "$local_app"

  else
    ct_clone_git_repository "$app_path" "$local_app"
  fi

  cat <<EOF >"$df_name"
# First stage builds the application
FROM $src_image as builder
# Add application sources to a directory that the assemble script expects them
# and set permissions so that the container runs without root access
USER 0
ADD app-src /tmp/src
RUN chown -R 1001:0 /tmp/src
$(echo "$s2i_args" | grep -o -e '\(-e\|--env\)[[:space:]=]\S*=\S*' | sed -e 's/-e /ENV /' -e 's/--env[ =]/ENV /')
# Check if CA autority is present on host and add it into Dockerfile
$([ -f "$(full_ca_file_path)" ] && echo "RUN cd /etc/pki/ca-trust/source/anchors && update-ca-trust extract")
USER $user_id
# Install the dependencies
RUN /usr/libexec/s2i/assemble
# Second stage copies the application to the minimal image
FROM $sec_image
# Copy the application source and build artifacts from the builder image to this one
COPY --from=builder \$HOME \$HOME
# Set the default command for the resulting image
CMD /usr/libexec/s2i/run
EOF

  # Check if -v parameter is present in s2i_args and add it into docker build command
  read -ra mount_options <<< "$(echo "$s2i_args" | grep -o -e '\(-v\)[[:space:]]\.*\S*' || true)"

  ct_build_image_and_parse_id "$df_name" "${mount_options[*]+${mount_options[*]}} -t $dst_image ."
  #shellcheck disable=SC2181
  if [ "$?" -ne 0 ]; then
    echo "  ERROR: Failed to to build $df_name" >&2
    return 1
  fi
  id_file="${APP_ID_FILE_DIR:?}"/"$RANDOM"
  echo "$APP_IMAGE_ID" > "$id_file"
  )
}

# ct_check_image_availability PUBLIC_IMAGE_NAME
# ----------------------------
# Pull an image from the public repositories to see if the image is already available.
# Argument: PUBLIC_IMAGE_NAME - string containing the public name of the image to pull
ct_check_image_availability() {
  local public_image_name=$1;

  # Try pulling the image to see if it is accessible
  if ! ct_pull_image "$public_image_name" &>/dev/null; then
    echo "$public_image_name could not be downloaded via 'docker'"
    return 1
  fi
}


# ct_check_latest_imagestreams
# -----------------------------
# Check if the latest version present in Makefile in the variable VERSIONS
# is present in all imagestreams.
# Also the latest tag in the imagestreams has to contain the latest version
ct_check_latest_imagestreams() {
    local latest_version=
    local test_lib_dir=

    # We only maintain imagestreams for RHEL and CentOS (Community)
    if [[ "$OS" =~ ^fedora.* ]] ; then
      echo "Imagestreams for Fedora are not maintained, skipping ct_check_latest_imagestreams"
      return 0
    fi

    # Check only lines which starts with VERSIONS
    latest_version=$(grep '^VERSIONS' Makefile | rev | cut -d ' ' -f 1 | rev )
    # Fall back to previous version if the latest is excluded for this OS
    [ -f "$latest_version/.exclude-$OS" ] && latest_version=$(grep '^VERSIONS' Makefile | rev | cut -d ' ' -f 2 | rev )
    # Only test the imagestream once, when the version matches
    # ignore the SC warning, $VERSION is always available

    test_lib_dir=$(dirname "$(readlink -f "$0")")
    python3 "${test_lib_dir}/show_all_imagestreams.py"
    # shellcheck disable=SC2153
    if [ "$latest_version" == "$VERSION" ]; then
      python3 "${test_lib_dir}/check_imagestreams.py" "$latest_version"
    else
      echo "Image version $VERSION is not latest, skipping ct_check_latest_imagestreams"
    fi
}

# ct_show_resources
# ----------------
# Prints the available resources
ct_show_resources()
{
  echo
  echo "$LINE"
  echo "Resources info:"
  echo "Memory:"
  free -h
  echo "Storage:"
  df -h || :
  echo "CPU"
  lscpu

  echo "$LINE"
  echo "Image ${IMAGE_NAME} information:"
  echo "$LINE"
  echo "Uncompressed size of the image: $(ct_get_image_size_uncompresseed "${IMAGE_NAME}")"
  echo "Compressed size of the image: $(ct_get_image_size_compresseed "${IMAGE_NAME}")"
  echo
}

# ct_clone_git_repository
# -----------------------------
# Argument: app_url - git URI pointing to a repository, supports "@" to indicate a different branch
# Argument: app_dir (optional) - name of the directory to clone the repository into
ct_clone_git_repository()
{
  local app_url=$1; shift
  local app_dir=$1

  # If app_url contains @, the string after @ is considered
  # as a name of a branch to clone instead of the main/master branch
  IFS='@' read -ra git_url_parts <<< "${app_url}"

  if [ -n "${git_url_parts[1]}" ]; then
    git_clone_cmd="git clone --branch ${git_url_parts[1]} ${git_url_parts[0]} ${app_dir}"
  else
    git_clone_cmd="git clone ${app_url} ${app_dir}"
  fi

  if ! $git_clone_cmd ; then
    echo "ERROR: Git repository ${app_url} cannot be cloned into ${app_dir}."
    return 1
  fi
}

# ct_get_uid_from_image
# -----------------------------
# Argument: user - user to get uid for inside the image
# Argument: src_image - image to use for user information
ct_get_uid_from_image()
{
  local user=$1; shift
  local src_image=$1
  local user_id=

  # NOTE: The '-eq' test is used to check if $user is numeric as it will fail if $user is not an integer
  if ! [ "$user" -eq "$user" ] 2>/dev/null && ! user_id=$(docker run --rm "$src_image" bash -c "id -u $user 2>/dev/null"); then
      echo "ERROR: id of user $user not found inside image $src_image."
      return 1
  else
      echo "${user_id:-$user}"
  fi
}

# ct_test_app_dockerfile
# -----------------------------
# Argument: dockerfile - path to a Dockerfile that will be used for building an image
#                        (must work with an application directory called 'app-src')
# Argument: app_url - git or local URI with a testing application, supports "@" to indicate a different branch
# Argument: body_regexp - PCRE regular expression that must match the response body
# Argument: app_dir - name of the application directory that is used in the Dockerfile
# Argument: build_args - build args that will be used for building an image
ct_test_app_dockerfile() {
  local dockerfile=$1
  local app_url=$2
  local expected_text=$3
  local app_dir=$4 # this is a directory that must match with the name in the Dockerfile
  local build_args=${5:-""}
  local port=8080
  local app_image_name=myapp
  local ret
  local cname=app_dockerfile
  local id_file

  if [ -z "$app_dir" ] ; then
    echo "ERROR: Option app_dir not set. Terminating the Dockerfile build."
    return 1
  fi

  if ! [ -r "${dockerfile}" ] || ! [ -s "${dockerfile}" ] ; then
    echo "ERROR: Dockerfile ${dockerfile} does not exist or is empty."
    echo "Terminating the Dockerfile build."
    return 1
  fi

  CID_FILE_DIR=${CID_FILE_DIR:-$(mktemp -d)}
  local dockerfile_abs
  dockerfile_abs=$(readlink -f "${dockerfile}")
  tmpdir=$(mktemp -d)
  pushd "$tmpdir" >/dev/null || return 1
  cp "${dockerfile_abs}" Dockerfile

  # Rewrite the source image to what we test
  sed -i -e "s|^FROM.*$|FROM $IMAGE_NAME|" Dockerfile
  # a bit more verbose, but should help debugging failures
  echo "Using this Dockerfile:"
  cat Dockerfile

  if [ -d "$app_url" ] ; then
    echo "Copying local folder: $app_url -> $app_dir."
    cp -Lr "$app_url" "$app_dir"
  else
    if ! ct_clone_git_repository "$app_url" "$app_dir" ; then
      echo "Terminating the Dockerfile build."
      return 1
    fi
  fi
  echo "Building '${app_image_name}' image using docker build"
  if ! ct_build_image_and_parse_id "" "-t ${app_image_name} . $build_args"; then
    echo "ERROR: The image cannot be built from ${dockerfile} and application ${app_url}."
    echo "Terminating the Dockerfile build."
    return 1
  fi
  id_file="${APP_ID_FILE_DIR:?}"/"$RANDOM"
  echo "$APP_IMAGE_ID" > "$id_file"

  if ! docker run -d --cidfile="${CID_FILE_DIR}/app_dockerfile" --rm "${app_image_name}"  ; then
    echo "ERROR: The image ${app_image_name} cannot be run for ${dockerfile} and application ${app_url}."
    echo "Terminating the Dockerfile build."
    return 1
  fi
  echo "Waiting for ${app_image_name} to start"
  ct_wait_for_cid "${CID_FILE_DIR}/app_dockerfile"

  ip="$(ct_get_cip "${cname}")"
  if [ -z "$ip" ]; then
    echo "ERROR: Cannot get container's IP address."
    return 1
  fi
  ct_test_response "http://$ip:${port}" 200 "${expected_text}"
  ret=$?

  [[ $ret -eq 0 ]] || docker logs "$(ct_get_cid "${cname}")"

  # cleanup
  docker kill "$(ct_get_cid "${cname}")"
  sleep 2
  docker rmi "${app_image_name}"
  popd >/dev/null || return 1
  rm -rf "${tmpdir}"
  rm -f "${CID_FILE_DIR}/${cname}"
  return $ret
}

# ct_check_testcase_result
# -----------------------------
# Check if testcase ended in success or error
# Argument: result - testcase result value
# Uses: $TESTCASE_RESULT - result of the testcase
# Uses: $IMAGE_NAME - name of the image being tested
ct_check_testcase_result() {
  local result="$1"
  if [[ "$result" != "0" ]]; then
    echo "Test for image '${IMAGE_NAME}' FAILED (exit code: ${result})"
    TESTCASE_RESULT=1
  fi
  return "$result"
}

# ct_update_test_result
# -----------------------------
# adds result to the $TEST_SUMMARY variable
# Argument: test_msg
# Argument: app_name
# Argument: test_name
# Argument: time_diff (optional)
# Uses: $TEST_SUMMARY - variable for storing test results
ct_update_test_result() {
  local test_msg="$1"
  local app_name="$2"
  local test_case="$3"
  local time_diff="${4:-}"
  printf -v TEST_SUMMARY "%s %s for '%s' %s (%s)\n" "${TEST_SUMMARY:-}" "${test_msg}" "${app_name}" "$test_case" "$time_diff"
}

# ct_run_tests_from_testset
# -----------------------------
# Runs all tests in $TEST_SET, prints result to
# the $TEST_SUMMARY variable
# Argument: app_name - application name to log
# Uses: $TEST_SET - set of test cases to run
# Uses: $TEST_SUMMARY - variable for storing test results
# Uses: $IMAGE_NAME - name of the image being tested
# Uses: $UNSTABLE_TESTS - set of tests, whose result can be ignored
# Uses: $IGNORE_UNSTABLE_TESTS - flag to ignore unstable tests
ct_run_tests_from_testset() {
  local app_name="${1:-appnamenotset}"
  local time_beg_pretty
  local time_beg
  local time_end
  local time_diff
  local test_msg
  local is_unstable

  # Let's store in the log what change do we test
  echo
  git show -s
  echo

  echo "Running tests for image ${IMAGE_NAME}"

  for test_case in $TEST_SET; do
    TESTCASE_RESULT=0
    # shellcheck disable=SC2076
    if [[ " ${UNSTABLE_TESTS[*]} " =~ " ${app_name} " ]] || \
       [[ " ${UNSTABLE_TESTS[*]} " =~ " ${test_case} " ]]; then
      is_unstable=1
    else
      is_unstable=0
    fi
    time_beg_pretty=$(ct_timestamp_pretty)
    time_beg=$(ct_timestamp_s)
    echo "-----------------------------------------------"
    echo "Running test $test_case (starting at $time_beg_pretty) ... "
    echo "-----------------------------------------------"
    $test_case
    ct_check_testcase_result $?
    time_end=$(ct_timestamp_s)
    if [ $TESTCASE_RESULT -eq 0 ]; then
      test_msg="[PASSED]"
    else
      if [ -n "${IGNORE_UNSTABLE_TESTS:-""}" ] && [ $is_unstable -eq 1 ]; then
        test_msg="[FAILED][UNSTABLE-IGNORED]"
      else
        test_msg="[FAILED]"
        TESTSUITE_RESULT=1
      fi
    fi
    # As soon as test is finished
    # switch the project from sclorg-test-<NUMBER> to default.
    if [ "${CT_OCP4_TEST:-false}" == "true" ]; then
      oc project default
    fi
    time_diff=$(ct_timestamp_diff "$time_beg" "$time_end")
    ct_update_test_result "${test_msg}" "${app_name}" "$test_case" "$time_diff"
  done
}

# ct_timestamp_s
# --------------
# Returns timestamp in seconds since unix era -- a large integer
function ct_timestamp_s() {
  date '+%s'
}

# ct_timestamp_pretty
# -----------------
# Returns timestamp readable to a human, like 2022-05-18 10:52:44+02:00
function ct_timestamp_pretty() {
  date --rfc-3339=seconds
}

# ct_timestamp_diff
# -----------------
# Computes a time diff between two timestamps
# Argument: start_date - Beginning (in seconds since unix era -- a large integer)
# Argument: final_date - End (in seconds since unix era -- a large integer)
# Returns: Time difference in format HH:MM:SS
function ct_timestamp_diff() {
  local start_date=$1
  local final_date=$2
  date -u -d "0 $final_date seconds - $start_date seconds" +"%H:%M:%S"
}

# ct_get_certificate_timestamp
# ----------------------------
# Looks into a running container into a specified file (certificate) and extracts
# a notBefore date.
# Argument: container - ID of a running container
# Argument: path - path to the certificate inside the running container
# Returns: timestamp (seconds since Unix era) for the certificate generation
function ct_get_certificate_timestamp() {
  local container=$1
  local path=$2
  date '+%s' --date="$(docker exec "$container" bash -c "cat $path" | openssl x509  -startdate -noout | grep notBefore | sed -e 's/notBefore=//')"
}

# ct_get_certificate_age_s
# ------------------------
# Looks into a running container into a specified file and retuns age of the certificate
# Argument: container - ID of a running container
# Argument: path - path inside the running container
# Returns: age of the certificate in seconds
function ct_get_certificate_age_s() {
  local container=$1
  local path=$2
  local now
  local cert_timestamp
  now=$(date '+%s')
  cert_timestamp=$(ct_get_certificate_timestamp "$container" "$path")
  echo $(( now - cert_timestamp ))
}

# ct_get_image_age_s
# ------------------
# Retuns age of a given image in seconds
# Argument: image_name - name of a given image
# Returns: age of the image in seconds
function ct_get_image_age_s() {
  local image_name=$1
  local now
  local image_created
  local image_timestamp
  now=$(date '+%s')
	# docker inspect returns format <date> <time> <timezone_diff> <timezone_name>
	# with is not understood by the date utility. Removing the <timezone_name> does
	# not change the meaning of the time, so we can safely remove it, which makes
	# the format read-able by the date utility
  image_created=$(docker inspect -f '{{.Created}}' "${image_name}" | awk '{print $1, $2, $3}')
  image_timestamp=$(date -d "${image_created}" '+%s')
  echo $(( now - image_timestamp ))
}

# ct_get_image_size_uncompresseed
# -------------------------------
# Shows uncompressed image size in MB
# Argument: image_name - image locally available
ct_get_image_size_uncompresseed() {
  local image_name=$1
  local size_bytes
  size_bytes=$(docker inspect "${image_name}" -f '{{.Size}}')
  echo "$(( size_bytes / 1024 / 1024 ))MB"
}

# ct_get_image_size_compresseed
# -------------------------------
# Shows compressed image size in MB
# This is a slight hack, that counts compressed size based on the compressed
# content. It might not be entirely same as what docker pull shows, but should
# be close enough.
# Argument: image_name - image locally available
ct_get_image_size_compresseed() {
  local image_name=$1
  local size_bytes
  size_bytes=$(docker save "${image_name}" | gzip - | wc --bytes)
  echo "$(( size_bytes / 1024 / 1024 ))MB"
}

# vim: set tabstop=2:shiftwidth=2:expandtab:
