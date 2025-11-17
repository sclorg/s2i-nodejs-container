#!/bin/bash
#
# Functions for tests for the Node.js image.
#
# IMAGE_NAME specifies a name of the candidate image used for testing.
# The image has to be available before this script is executed.
#

THISDIR=$(dirname ${BASH_SOURCE[0]})

source "${THISDIR}/test-lib.sh"
source "${THISDIR}/test-lib-openshift.sh"

test_dir="$(readlink -f $(dirname ${BASH_SOURCE[0]}))"

info() {
  echo -e "\n\e[1m[INFO] $@...\e[0m\n"
}

check_prep_result() {
  if [ $1 -ne 0 ]; then
    ct_update_test_result "[FAILED]" "$2" "preparation"
    TESTSUITE_RESULT=1
    return $1
  fi
}

image_exists() {
  docker inspect $1 1>/dev/null
}

container_exists() {
  image_exists $(cat $cid_file)
}

container_ip() {
  docker inspect --format="{{ .NetworkSettings.IPAddress }}" $(cat $cid_file)
}

container_logs() {
  docker logs $(cat $cid_file)
}

run_s2i_build() {
  ct_s2i_build_as_df file://${test_dir}/test-app ${IMAGE_NAME} ${IMAGE_NAME}-testapp ${s2i_args} $(ct_build_s2i_npm_variables) $1
}

run_s2i_build_fips() {
  ct_s2i_build_as_df file://${test_dir}/test-fips ${IMAGE_NAME} ${IMAGE_NAME}-testfips ${s2i_args} $(ct_build_s2i_npm_variables) $1
}

run_s2i_build_proxy() {
  ct_s2i_build_as_df file://${test_dir}/test-hw ${IMAGE_NAME} ${IMAGE_NAME}-testhw ${s2i_args} $(ct_build_s2i_npm_variables) -e HTTP_PROXY=$1 -e http_proxy=$1 -e HTTPS_PROXY=$2 -e https_proxy=$2
}

run_s2i_build_client() {
  ct_s2i_build_as_df_build_args \
    "file://${test_dir}/$1" "${IMAGE_NAME}" "${IMAGE_NAME}-$1" "--ulimit nofile=4096:4096" \
    ${s2i_args} \
    $(ct_build_s2i_npm_variables) -e NODE_ENV=development
}

run_s2i_build_binary() {
  ct_s2i_build_as_df file://${test_dir}/test-binary ${IMAGE_NAME} ${IMAGE_NAME}-testbinary ${s2i_args} $(ct_build_s2i_npm_variables) $1
}

run_s2i_multistage_build() {
  ct_s2i_multistage_build file://${test_dir}/test-app ${FULL_IMAGE} ${IMAGE_NAME} ${IMAGE_NAME}-testapp $(ct_build_s2i_npm_variables)
}

prepare_dummy_git_repo() {
  git init
  for key in "${!gitconfig[@]}"; do
    git config --local "$key" "${gitconfig[$key]}"
  done
  git add --all
  git commit -m "Sample commit"
}

prepare_client_repo() {
  git clone \
    --config advice.detachedHead="false" \
    --branch "$3" --depth 1 \
    "$2" "$1"
  pushd "$1" >/dev/null || return
  for key in "${!gitconfig[@]}"; do
    git config --local "$key" "${gitconfig[$key]}"
  done
  popd >/dev/null || return
}

prepare_minimal_build() {
  suffix=$1
  # Build the app using the full assemble-capable image
  case "$suffix" in
    testapp)
      run_s2i_multistage_build #>/tmp/build-log 2>&1
      ;;
    testhw)
      IMAGE_NAME=$FULL_IMAGE run_s2i_build_proxy http://user.password@0.0.0.0:8000 https://user.password@0.0.0.0:8000 >/tmp/build-log 2>&1
      # Get the application from the assembled image and into the minimal
      tempdir=$(mktemp -d)
      chown 1001:0 "$tempdir"
      docker run -u 0 --rm -ti -v "$tempdir:$tempdir:Z" "$FULL_IMAGE-$suffix"  bash -c "cp -ar /opt/app-root/src $tempdir"
  pushd "$tempdir" >/dev/null || return
  cat <<EOF >Dockerfile
FROM $IMAGE_NAME
ADD src/* /opt/app-root/src
CMD /usr/libexec/s2i/run
EOF
      # Check if CA autority is present on host and add it into Dockerfile
      [ -f "$(full_ca_file_path)" ] && cat <<EOF >>Dockerfile
USER 0
RUN cd /etc/pki/ca-trust/source/anchors && update-ca-trust extract
USER 1001
EOF
      docker build -t "$IMAGE_NAME-$suffix" $(ct_build_s2i_npm_variables | grep -o -e '\(-v\)[[:space:]]\.*\S*') .
      popd >/dev/null || return
      ;;
    *)
      echo "Please specify a valid test application"
      return 1
      ;;
  esac

}

prepare() {
  if ! image_exists ${IMAGE_NAME}; then
    echo "ERROR: The image ${IMAGE_NAME} must exist before this script is executed."
    return 1
  fi

  case "$1" in
    # TODO: STI build require the application is a valid 'GIT' repository, we
    # should remove this restriction in the future when a file:// is used.
    app|hw|fips|express-webapp|binary)
      pushd "${test_dir}/test-${1}" >/dev/null
      prepare_dummy_git_repo
      popd >/dev/null
      ;;
    *)
      if [[ "$TEST_LIST_CLIENTS" == *"${test_case}"* ]];
      then
        PREFIX=$1
        PREFIX=${PREFIX//-/}
        REPO="${PREFIX^^}"_REPO
        REVISION="${PREFIX^^}"_REVISION
        prepare_client_repo "${test_dir}/$1" "${!REPO}" "${!REVISION}"
      else
        echo "Please specify a valid test application"
        return 1
      fi
      ;;
  esac
}

run_test_application() {
  case "$1" in
    app|fips|hw|express-webapp|binary)
      cid_file=$CID_FILE_DIR/$(mktemp -u -p . --suffix=.cid)
      docker run -d --user=100001 $(ct_mount_ca_file) --rm --cidfile=${cid_file} $2 ${IMAGE_NAME}-test$1
      ;;
    *)
      echo "No such test application"
      return 1
      ;;
    esac
}

run_test_application_with_quoted_args() {
  case "$1" in
  app | fips | hw | express-webapp | binary)
    cid_file=$CID_FILE_DIR/$(mktemp -u -p . --suffix=.cid)
    docker run -d --user=100001 $(ct_mount_ca_file) --rm --cidfile=${cid_file} "$2" ${IMAGE_NAME}-test$1
    ;;
  *)
    echo "No such test application"
    return 1
    ;;
  esac
}

run_client_test_suite() {
  cid_file=$CID_FILE_DIR/$(mktemp -u -p . --suffix=.cid)
  local cmd="npm test"
  # Skip style check tests
  [ "$1" == "prom-client" ] && cmd="sed -i.bak 's/&& npm run check-prettier //g' package.json && $cmd"
  docker run --user=100001 $(ct_mount_ca_file) --rm --cidfile=${cid_file} ${IMAGE_NAME}-$1 bash -c "$cmd"
}

kill_test_application() {
  if [[ -f "$cid_file" ]]; then
    docker kill $(cat $cid_file)
  fi
}

wait_for_cid() {
  local max_attempts=20
  local sleep_time=1
  local attempt=1
  local result=1
  while [ $attempt -le $max_attempts ]; do
    [ -f $cid_file ] && [ -s $cid_file ] && break
    echo "Waiting for container start..."
    attempt=$(( $attempt + 1 ))
    sleep $sleep_time
  done
}

test_s2i_usage() {
  echo "Testing 's2i usage'..."
  ct_s2i_usage ${IMAGE_NAME} ${s2i_args} &>/dev/null
  ct_check_testcase_result $?
}

test_docker_run_usage() {
  echo "Testing 'docker run' usage..."
  docker run --rm ${IMAGE_NAME} &>/dev/null
  ct_check_testcase_result $?
}

test_connection() {
  echo "Testing HTTP connection..."
  local max_attempts=10
  local sleep_time=1
  local attempt=1
  local result=1
  while [ $attempt -le $max_attempts ]; do
    echo "Sending GET request to http://$(container_ip):${test_port}/"
    response_code=$(curl -s -w %{http_code} -o /dev/null http://$(container_ip):${test_port}/)
    status=$?
    if [ $status -eq 0 ]; then
      if [ $response_code -eq 200 ]; then
        result=0
      fi
      break
    fi
    attempt=$(( $attempt + 1 ))
    sleep $sleep_time
  done
  return $result
}

scl_usage() {
  # Verify the 'usage' script is working properly when running the base image with 's2i usage ...'
  local run_cmd="$1"
  local expected="$2"

  echo "Testing the image SCL enable ..."
  out=$(docker run --rm ${IMAGE_NAME} /bin/bash -c "${run_cmd}")
  if ! echo "${out}" | grep -q "${expected}"; then
    echo "ERROR[/bin/bash -c "${run_cmd}"] Expected '${expected}', got '${out}'"
    return 1
  fi
  out=$(docker exec $(cat ${cid_file}) /bin/bash -c "${run_cmd}" 2>&1)
  if ! echo "${out}" | grep -q "${expected}"; then
    echo "ERROR[exec /bin/bash -c "${run_cmd}"] Expected '${expected}', got '${out}'"
    return 1
  fi
  out=$(docker exec $(cat ${cid_file}) /bin/sh -ic "${run_cmd}" 2>&1)
  if ! echo "${out}" | grep -q "${expected}"; then
    echo "ERROR[exec /bin/sh -ic "${run_cmd}"] Expected '${expected}', got '${out}'"
    return 1
  fi
}
function test_scl_usage() {
  VERSION=${VERSION//-minimal/}
  if [ "$VERSION" == "22" ]; then
    scl_usage "node-$VERSION --version" "v$VERSION."
  else
    scl_usage "node --version" "v$VERSION."
  fi
  ct_check_testcase_result $?
}

validate_default_value() {
  local label=$1

  IFS=':' read -a label_vals <<< $(docker inspect -f "{{index .Config.Labels \"$label\"}}" ${IMAGE_NAME})
  label_var=${label_vals[0]}
  default_label_val=${label_vals[1]}

  actual_label_val=$(docker run --rm $IMAGE_NAME /bin/bash -c "echo $"$label_var)

  if [ "$actual_label_val" != "$default_label_val" ]; then
    echo "ERROR default value for $label with environment variable $label_var; Expected $default_label_val, got $actual_label_val"
    return 1
  fi
}

# Gets the NODE_ENV environment variable from the container.
get_node_env_from_container() {
  local dev_mode="$1"
  local node_env="$2"

  IFS=':' read -a label_val <<< $(docker inspect -f '{{index .Config.Labels "com.redhat.dev-mode"}}' $IMAGE_NAME)
  dev_mode_label_var="${label_val[0]}"

  echo $(docker run --rm --env $dev_mode_label_var=$dev_mode --env NODE_ENV=$node_env $IMAGE_NAME /bin/bash -c 'echo "$NODE_ENV"')
}

# Ensures that a docker container run with '--env NODE_ENV=$current_val' produces a NODE_ENV value of $expected when
# DEV_MODE=dev_mode.
validate_node_env() {
  local current_val="$1"
  local dev_mode_val="$2"
  local expected="$3"

  actual=$(get_node_env_from_container "$dev_mode_val" "$current_val")
  if [ "$actual" != "$expected" ]; then
    echo "ERROR default value for NODE_ENV when development mode is $dev_mode_val; should be $expected but is $actual"
    return 1
  fi
}

test_dev_mode() {
  local app=$1
  local dev_mode=$2
  local node_env=$3

  echo "Testing $app DEV_MODE=$dev_mode NODE_ENV=$node_env"

  run_test_application $app "-e DEV_MODE=$dev_mode"
  wait_for_cid

  test_connection
  ct_check_testcase_result $?

  logs=$(container_logs)
  echo ${logs} | grep -q DEV_MODE=$dev_mode
  ct_check_testcase_result $?
  echo ${logs} | grep -q DEBUG_PORT=5858
  ct_check_testcase_result $?
  echo ${logs} | grep -q NODE_ENV=$node_env
  ct_check_testcase_result $?

  kill_test_application
}

test_incremental_build() {
  npm_variables=$(ct_build_s2i_npm_variables)
  build_log1=$(ct_s2i_build_as_df file://${test_dir}/test-incremental ${IMAGE_NAME} ${IMAGE_NAME}-testapp ${s2i_args} ${npm_variables})
  ct_check_testcase_result $?
  build_log2=$(ct_s2i_build_as_df file://${test_dir}/test-incremental ${IMAGE_NAME} ${IMAGE_NAME}-testapp ${s2i_args} ${npm_variables} --incremental)
  ct_check_testcase_result $?
  first=$(echo "$build_log1" | grep -o -e "added [0-9]* packages" | awk '{ print $2 }')
  second=$(echo "$build_log2" | grep -o -e "added [0-9]* packages" | awk '{ print $2 }')
  if [ "$first" == "$second" ]; then
      echo "ERROR Incremental build failed: both builds installed $first packages"
      ct_check_testcase_result 1
  fi

}

test_node_cmd() {
  local app=$1
  local node_env=$2
  local init_wrapper=$3
  local node_cmd=$4

  run_test_application_with_quoted_args $app "-e NODE_ENV=$node_env -e INIT_WRAPPER=$init_wrapper -e NODE_CMD=$node_cmd"
  logs=$(container_logs)
  wait_for_cid

  test_connection
  ct_check_testcase_result $?

  logs=$(container_logs)
  echo ${logs} | grep -q DEBUG_PORT=5858
  ct_check_testcase_result $?
  echo ${logs} | grep -q NODE_ENV=$node_env
  ct_check_testcase_result $?
  echo ${logs} | grep -q INIT_WRAPPER=$init_wrapper
  ct_check_testcase_result $?
  echo ${logs} | grep -q NODE_CMD="$node_cmd"
  ct_check_testcase_result $?

  kill_test_application
}

# test express webapp
run_s2i_build_express_webapp() {
  local result
  prepare express-webapp
  check_prep_result $? express-webapp || return
  ct_s2i_build_as_df file://${test_dir}/test-express-webapp ${IMAGE_NAME} ${IMAGE_NAME}-testexpress-webapp ${s2i_args} $(ct_build_s2i_npm_variables)
  run_test_application express-webapp
  wait_for_cid
  ct_test_response http://$(container_ip):${test_port} 200 'Welcome to Express Testing Application'
  result=$?
  kill_test_application
  return $result
}

function test_build_express_webapp() {
  echo "Running express webapp test"
  run_s2i_build_express_webapp
  ct_check_testcase_result $?
}

function test_running_client_js {
  echo "Running $1 test suite"
  prepare "$1"
  check_prep_result $? $1 || return
  run_s2i_build_client "$1"
  ct_check_testcase_result $? || return
  run_client_test_suite "$1"
  ct_check_testcase_result $? || return
}

function test_client_express() {
  echo "Running express client test"
  test_running_client_js express
}

function test_client_pino() {
  echo "Running pino client test"
  test_running_client_js pino
}

function test_client_prom() {
  echo "Running prom-client test"
  test_running_client_js prom-client
}

function test_client_opossum() {
  echo "Running opossum client test"
  test_running_client_js opossum
}

function test_client_kube() {
  echo "Running kube-service-bindings client test"
  test_running_client_js kube-service-bindings
}

function test_client_faas() {
  echo "Running faas-js-runtime client test"
  test_running_client_js faas-js-runtime
}

function test_client_cloudevents() {
  echo "Running CloudEvents client test"
  test_running_client_js cloudevents
}

function test_client_fastify() {
  if [[ "${VERSION}" == *"minimal"* ]]; then
    VERSION=$(echo "${VERSION}" | cut -d "-" -f 1)
  fi
  echo "Running fastify client test"
  test_running_client_js fastify
}

function test_check_build_using_dockerfile() {
  info "Check building using a Dockerfile"
  ct_test_app_dockerfile ${THISDIR}/examples/from-dockerfile/Dockerfile 'https://github.com/sclorg/nodejs-ex.git' 'Node.js Crud Application' app-src "--ulimit nofile=4096:4096"
  ct_check_testcase_result $?
  ct_test_app_dockerfile ${THISDIR}/examples/from-dockerfile/Dockerfile.s2i 'https://github.com/sclorg/nodejs-ex.git' 'Node.js Crud Application' app-src "--ulimit nofile=4096:4096"
  ct_check_testcase_result $?
}
function test_npm_functionality() {
  echo "Testing npm availability"
  ct_npm_works
  ct_check_testcase_result $?
}

function test_nodemon_removed() {
  # Test that the development dependencies (nodemon) have been removed (npm prune)
  devdep=$(docker run --rm ${IMAGE_NAME}-testapp /bin/bash -c "! test -d ./node_modules/nodemon")
  ct_check_testcase_result "$?"
}

function test_nodemon_present() {
  # Test that the development dependencies (nodemon) have been removed (npm prune)
  devdep=$(docker run --rm ${IMAGE_NAME}-testapp /bin/bash -c "test -d ./node_modules/nodemon")
  ct_check_testcase_result "$?"
}

function test_nodejs_fips_mode() {
  # Test that nodejs behaves as expected in fips mode
  local is_fips_enabled

  # Read fips mode from host in case exists
  if [[ -f /proc/sys/crypto/fips_enabled ]]; then
    is_fips_enabled=$(cat /proc/sys/crypto/fips_enabled)
  else
    is_fips_enabled="0"
  fi
  if [[ "$is_fips_enabled" == "0" ]]; then
    # FIPS disabled -- crypto.getFips() should return 0
    echo "Fips should be disabled"
    docker run --rm ${IMAGE_NAME}-testfips /bin/bash -c "node test.js"
    ct_check_testcase_result "$?"
  else
    # FIPS enabled -- crypto.getFips() should return 1
    echo "Fips should be enabled"
    docker run --rm ${IMAGE_NAME}-testfips /bin/bash -c "! node test.js"
    ct_check_testcase_result "$?"
  fi
}

function test_npm_cache_cleared() {
  # Test that the npm cache has been cleared
  cache_loc=$(docker run --rm ${IMAGE_NAME}-testapp /bin/bash -c "npm config get cache")
  devdep=$(docker run --rm ${IMAGE_NAME}-testapp /bin/bash -c "! test -d $cache_loc")
  ct_check_testcase_result "$?"
}

function test_npm_cache_exists() {
  # Test that the npm cache has been cleared
  devdep=$(docker run --rm ${IMAGE_NAME}-testapp /bin/bash -c "test -d \$(npm config get cache)")
  ct_check_testcase_result "$?"
}

function test_npm_tmp_cleared() {
  # Test that the npm tmp has been cleared
  devdep=$(docker run --rm ${IMAGE_NAME}-testapp /bin/bash -c "! ls \$(npm config get tmp)/npm-* 2>/dev/null")
  ct_check_testcase_result "$?"
}

function test_dev_mode_false_production() {
  # DEV_MODE=false NODE_ENV=production
  test_dev_mode app false production
}

function test_dev_mode_true_development() {
  # DEV_MODE=true NODE_ENV=development
  test_dev_mode app true development
}

function test_node_cmd_production_init_wrapper_false() {
  test_node_cmd app production false "node server.js"
}

function test_node_cmd_development_init_wrapper_true() {
  # NODE_ENV=development INIT_WRAPPER=true NODE_CMD="node server.js"
  test_node_cmd app development true "node server.js"
}

function test_node_cmd_production_init_wrapper_true() {
  # NODE_ENV=production INIT_WRAPPER=true NODE_CMD="node server.js"
  test_node_cmd app production true "node server.js"
}

function test_node_cmd_development_init_wrapper_false() {
  # NODE_ENV=development INIT_WRAPPER=false NODE_CMD="node server.js"
  test_node_cmd app development false "node server.js"
}

function test_init_wrapper_true_development() {
  # NODE_ENV=development INIT_WRAPPER=true
  test_node_cmd app development true
}

function test_init_wrapper_false_development() {
  # NODE_ENV=development INIT_WRAPPER=true
  test_node_cmd app development false
}

function test_dev_mode_false_development() {
  # DEV_MODE=false NODE_ENV=development
  test_dev_mode app false development
}

function test_run_app_application() {
  # Verify that the HTTP connection can be established to test application container
  run_test_application app
  # Wait for the container to write it's CID file
  wait_for_cid
}

function test_run_fips_app_application() {
  local is_fips_enabled

  # Read fips mode from host in case exists
  if [[ -f /proc/sys/crypto/fips_enabled ]]; then
    is_fips_enabled=$(cat /proc/sys/crypto/fips_enabled)
  else
    is_fips_enabled="0"
  fi
  if [[ "$is_fips_enabled" == "1" ]]; then
    # Verify that the HTTP connection can be established to test application container
    run_test_application fips
    # Wait for the container to write it's CID file
    wait_for_cid
    ct_check_testcase_result $?
    kill_test_application
  fi
}

function test_run_hw_application() {
  # Verify that the HTTP connection can be established to test application container
  run_test_application hw
  # Wait for the container to write it's CID file
  wait_for_cid
  ct_check_testcase_result $?
  kill_test_application
}

function test_run_binary_application() {
  if [[ "${VERSION}" == "22" ]]; then
    if [[ "${OS}" == "c10s" ]]; then
      # This tests is suppressed for version 22
      # openssl/engine.h is going to be deprecated and therefore till node-rdkafka is not solve we can skip it.
      # https://src.fedoraproject.org/rpms/openssl/c/e67e9d9c40cd2cb9547e539c658e2b63f2736762
      # https://pkgs.devel.redhat.com/cgit/rpms/openssl/tree/openssl.spec?h=rhel-10-main#n508
      echo "openssl-devel-engine is deprecated. Test is skipped."
      return 0
    fi
  fi
  prepare binary
  check_prep_result $? binary || return
  run_s2i_build_binary
  ct_check_testcase_result $?
  # Verify that the HTTP connection can be established to test application container
  run_test_application binary
  # Wait for the container to write it's CID file
  wait_for_cid
  kill_test_application
}

function test_safe_logging() {
  if [[ $(grep redacted /tmp/build-log | wc -l) -eq 4 ]]; then
      grep redacted /tmp/build-log
      ct_check_testcase_result 0
  else
      echo "Some proxy log-in credentials were left in log file"
      grep Setting /tmp/build-log
      ct_check_testcase_result 1
  fi
}


function ct_pull_or_import_postgresql() {
  postgresql_image="quay.io/sclorg/postgresql-15-c9s"
  image_short="postgresql"
  image_tag="postgresql:15-c9s"
  # Variable CVP is set by CVP pipeline
  if [ "${CVP:-0}" -eq "0" ]; then
    # In case of container or OpenShift 4 tests
    # Pull image before going through tests
    # Exit in case of failure, because postgresql container is mandatory
    ct_pull_image "${postgresql_image}" "true"
  else
    # Import postgresql-15-c9s image before running tests on CVP
    oc import-image "${image_short}:latest" --from="${postgresql_image}:latest" --insecure=true --confirm
    # Tag postgresql image to "postgresql:10" which is expected by test suite
    oc tag "${image_short}:latest" "${image_tag}"
  fi
}

# Check the imagestream
function test_nodejs_imagestream() {
  local ret_val=0
  if [[ "${VERSION}" == *"minimal"* ]]; then
    VERSION=$(echo "${VERSION}" | cut -d "-" -f 1)
  fi
  ct_os_test_image_stream_quickstart \
    "${THISDIR}/imagestreams/nodejs-${OS//[0-9]/}.json" \
    "https://raw.githubusercontent.com/sclorg/nodejs-ex/${BRANCH_TO_TEST}/openshift/templates/nodejs-postgresql-persistent.json" \
    "${IMAGE_NAME}" \
    'nodejs' \
    "Node.js Crud Application" \
    8080 http 200 \
    "-p SOURCE_REPOSITORY_REF=${BRANCH_TO_TEST} -p SOURCE_REPOSITORY_URL=https://github.com/sclorg/nodejs-ex.git -p NODEJS_VERSION=${VERSION} -p NAME=nodejs-testing
     -p DATABASE_USER=testu \
     -p DATABASE_PASSWORD=testpwd \
     -p DATABASE_ADMIN_PASSWORD=testadminpwd" \
     "quay.io/sclorg/postgresql-15-c9s|postgresql:15-c9s"|| ret_val=1
}

function test_nodejs_s2i_container() {
  ct_os_test_s2i_app "${IMAGE_NAME}" \
    "https://github.com/sclorg/s2i-nodejs-container.git" \
    "test/test-app" \
    "This is a node.js echo service"
}

function test_nodejs_s2i_app_ex() {
  ct_os_test_s2i_app "${IMAGE_NAME}" \
    "https://github.com/sclorg/nodejs-ex.git" \
    "." \
    "Node.js Crud Application"
}

function test_nodejs_s2i_templates() {
  local ret_val=0
  if [[ "${VERSION}" == *"minimal"* ]]; then
    VERSION=$(echo "${VERSION}" | cut -d "-" -f 1)
  fi
  # TODO
  # MongoDB is not supported at all.
  # Let's disable it or replace it with mariadb
  ct_os_test_template_app "${IMAGE_NAME}" \
    "https://raw.githubusercontent.com/sclorg/nodejs-ex/${BRANCH_TO_TEST}/openshift/templates/nodejs-postgresql-persistent.json" \
    nodejs \
    "Node.js Crud Application" \
    8080 http 200 \
    "-p SOURCE_REPOSITORY_REF=${BRANCH_TO_TEST} -p SOURCE_REPOSITORY_URL=https://github.com/sclorg/nodejs-ex.git -p NODEJS_VERSION=${VERSION} -p NAME=nodejs-testing
     -p DATABASE_USER=testu \
     -p DATABASE_PASSWORD=testpwd \
     -p DATABASE_ADMIN_PASSWORD=testadminpwd" \
    "quay.io/sclorg/postgresql-15-c9s|postgresql:15-c9s" || ret_val=1

  return $ret_val
}

function test_latest_imagestreams() {
  local result=1
  # Switch to root directory of a container
  pushd "${test_dir}/.." >/dev/null || return 1
  ct_check_latest_imagestreams
  result=$?
  popd >/dev/null || return 1
  return $result
}

function cleanup() {
  info "Cleaning up the test application image ${IMAGE_NAME}-testapp"
  if image_exists ${IMAGE_NAME}-testapp; then
    info "Image ${IMAGE_NAME}-testapp exist...removing it"
    docker rmi -f ${IMAGE_NAME}-testapp
    echo $?
    info "Removed by docker rmi ${IMAGE_NAME}-testapp"
  fi
}

# vim: set tabstop=2:shiftwidth=2:expandtab:
