# shellcheck disable=SC2148
if [ -z "${sourced_test_lib_openshift:-}" ]; then
  sourced_test_lib_openshift=1
else
  return 0
fi

# shellcheck shell=bash
# some functions are used from test-lib.sh, that is usually in the same dir
# shellcheck source=/dev/null
source "$(dirname "${BASH_SOURCE[0]}")"/test-lib.sh

# Set of functions for testing docker images in OpenShift using 'oc' command

# A variable containing the overall test result
#   TESTSUITE_RESULT=0
# And the following trap must be set, in the beginning of the test script:
#   trap ct_os_cleanup EXIT SIGINT
TESTSUITE_RESULT=0

function ct_os_cleanup() {
  local exit_code=$?
  echo "${TEST_SUMMARY:-}"
  if [ "$TESTSUITE_RESULT" -ne 0 ] || [ "$exit_code" -ne 0 ]; then
    # shellcheck disable=SC2153
    echo "OpenShift tests for ${IMAGE_NAME} failed."
    exit 1
  else
    # shellcheck disable=SC2153
    echo "OpenShift tests for ${IMAGE_NAME} succeeded."
    exit 0
  fi
}

# ct_os_check_compulsory_vars
# ---------------------------
# Check the compulsory variables:
# * IMAGE_NAME specifies a name of the candidate image used for testing.
# * VERSION specifies the major version of the MariaDB in format of X.Y
# * OS specifies RHEL version (e.g. OS=rhel8)
function ct_os_check_compulsory_vars() {
  # shellcheck disable=SC2016
  test -n "${IMAGE_NAME-}" || ( echo 'make sure $IMAGE_NAME is defined' >&2 ; exit 1)
  # shellcheck disable=SC2016
  test -n "${VERSION-}" || ( echo 'make sure $VERSION is defined' >&2 ; exit 1)
  # shellcheck disable=SC2016
  test -n "${OS-}" || ( echo 'make sure $OS is defined' >&2 ; exit 1)
}

# ct_os_get_status
# --------------------
# Returns status of all objects to make debugging easier.
function ct_os_get_status() {
  oc get all
  oc status
  oc status --suggest
}

# ct_os_print_logs
# --------------------
# Returns status of all objects and logs from all pods.
function ct_os_print_logs() {
  ct_os_get_status
  while read -r pod_name; do
    echo "INFO: printing logs for pod ${pod_name}"
    oc logs "${pod_name}"
  done < <(oc get pods --no-headers=true -o custom-columns=NAME:.metadata.name)
}

# ct_os_enable_print_logs
# --------------------
# Enables automatic printing of pod logs on ERR.
function ct_os_enable_print_logs() {
  set -E
  trap ct_os_print_logs ERR
}

# ct_get_public_ip
# --------------------
# Returns best guess for the IP that the node is accessible from other computers.
# This is a bit funny heuristic, simply goes through all IPv4 addresses that
# hostname -I returns and de-prioritizes IP addresses commonly used for local
# addressing. The rest of addresses are taken as public with higher probability.
function ct_get_public_ip() {
  local hostnames
  local public_ip=''
  local found_ip
  hostnames=$(hostname -I)
  for guess_exp in '127\.0\.0\.1' '192\.168\.[0-9\.]*' '172\.[0-9\.]*' \
                   '10\.[0-9\.]*' '[0-9\.]*' ; do
    found_ip=$(echo "${hostnames}" | grep -oe "${guess_exp}")
    if [ -n "${found_ip}" ] ; then
      # shellcheck disable=SC2001
      hostnames=$(echo "${hostnames}" | sed -e "s/${found_ip}//")
      public_ip="${found_ip}"
    fi
  done
  if [ -z "${public_ip}" ] ; then
    echo "ERROR: public IP could not be guessed." >&2
    return 1
  fi
  echo "${public_ip}"
}

# ct_os_run_in_pod POD_NAME CMD
# --------------------
# Runs [cmd] in the pod specified by prefix [pod_prefix].
# Arguments: pod_name - full name of the pod
# Arguments: cmd - command to be run in the pod
function ct_os_run_in_pod() {
  local pod_name="$1" ; shift

  oc exec "$pod_name" -- "$@"
}

# ct_os_get_service_ip SERVICE_NAME
# --------------------
# Returns IP of the service specified by [service_name].
# Arguments: service_name - name of the service
function ct_os_get_service_ip() {
  local service_name="${1}" ; shift
  local ocp_docker_address="172\.30\.[0-9\.]*"
  if [ "${CVP:-0}" -eq "1" ]; then
    # shellcheck disable=SC2034
    ocp_docker_address="172\.27\.[0-9\.]*"
  fi
  # shellcheck disable=SC2016
  oc get "svc/${service_name}" -o yaml | grep clusterIP | \
     cut -d':' -f2 | grep -oe "$ocp_docker_address"
}


# ct_os_get_all_pods_status
# --------------------
# Returns status of all pods.
function ct_os_get_all_pods_status() {
  oc get pods -o custom-columns=Ready:status.containerStatuses[0].ready,NAME:.metadata.name
}

# ct_os_get_all_pods_name
# --------------------
# Returns the full name of all pods.
function ct_os_get_all_pods_name() {
  oc get pods --no-headers -o custom-columns=NAME:.metadata.name
}

# ct_os_get_pod_status POD_PREFIX
# --------------------
# Returns status of the pod specified by prefix [pod_prefix].
# Note: Ignores -build and -deploy pods
# Arguments: pod_prefix - prefix or whole ID of the pod
function ct_os_get_pod_status() {
  local pod_prefix="${1}" ; shift
  ct_os_get_all_pods_status | grep -e "${pod_prefix}" | grep -Ev "(build|deploy)$" \
                            | awk '{print $1}' | head -n 1
}

# ct_os_get_build_pod_status POD_PREFIX
# --------------------
# Returns status of the build pod specified by prefix [pod_prefix].
# Arguments: pod_prefix - prefix or whole ID of the pod
function ct_os_get_build_pod_status() {
  local pod_prefix="${1}" ; shift
  local query="custom-columns=NAME:.metadata.name,Ready:status.phase"
  oc get pods -o "$query" | grep -e "${pod_prefix}" | grep -E "\-build\s" \
                          | sort -u | awk '{print $2}' | tail -n 1
}

# ct_os_get_buildconfig_pod_name POD_PREFIX
# ----------------------------
# Returns status of the buildconfig pod specified by prefix [pod_prefix].
# Argument: pod_prefix - prefix
function ct_os_get_buildconfig_pod_name() {
  local pod_prefix="${1}" ; shift
  local query="custom-columns=NAME:.metadata.name"
  oc get bc -o "$query" | grep -e "${pod_prefix}" | sort -u | tail -n 1
}

# ct_os_get_pod_name POD_PREFIX
# --------------------
# Returns the full name of pods specified by prefix [pod_prefix].
# Note: Ignores -build and -deploy pods
# Arguments: pod_prefix - prefix or whole ID of the pod
function ct_os_get_pod_name() {
  local pod_prefix="${1}" ; shift
  ct_os_get_all_pods_name | grep -e "^${pod_prefix}" | grep -Ev "(build|deploy)$"
}

# ct_os_get_pod_ip POD_NAME
# --------------------
# Returns the ip of the pod specified by [pod_name].
# Arguments: pod_name - full name of the pod
function ct_os_get_pod_ip() {
  local pod_name="${1}"
  oc get pod "$pod_name" --no-headers -o custom-columns=IP:status.podIP
}

# ct_os_get_sti_build_logs
# -----------------
# Return logs from sti_build
# Arguments: pod_name
function ct_os_get_sti_build_logs() {
  local pod_prefix="${1}"
  oc status --suggest
  pod_name=$(ct_os_get_buildconfig_pod_name "${pod_prefix}")
  # Print logs but do not failed. Just for traces
  if [ x"${pod_name}" != "x" ]; then
    oc logs "bc/$pod_name" || return 0
  else
    echo "Build config bc/$pod_name does not exist for some reason."
    echo "Import probably failed."
  fi
}

# ct_os_check_pod_readiness POD_PREFIX STATUS
# --------------------
# Checks whether the pod is ready.
# Arguments: pod_prefix - prefix or whole ID of the pod
# Arguments: status - expected status (true, false)
function ct_os_check_pod_readiness() {
  local pod_prefix="${1}" ; shift
  local status="${1}" ; shift
  test "$(ct_os_get_pod_status "${pod_prefix}")" == "${status}"
}

# ct_os_wait_pod_ready POD_PREFIX TIMEOUT
# --------------------
# Wait maximum [timeout] for the pod becomming ready.
# Arguments: pod_prefix - prefix or whole ID of the pod
# Arguments: timeout - how many seconds to wait seconds
function ct_os_wait_pod_ready() {
  local pod_prefix="${1}" ; shift
  local timeout="${1}" ; shift
  # If there is a build pod - wait for it to finish first
  sleep 3
  if ct_os_get_all_pods_name | grep -E "${pod_prefix}.*-build"; then
    SECONDS=0
    echo -n "Waiting for ${pod_prefix} build pod to finish ..."
    while ! [ "$(ct_os_get_build_pod_status "${pod_prefix}")" == "Succeeded" ] ; do
      echo -n "."
      if [ "${SECONDS}" -gt "${timeout}0" ]; then
        echo " FAIL"
        ct_os_print_logs || :
        ct_os_get_sti_build_logs "${pod_prefix}" || :
        return 1
      fi
      sleep 3
    done
    echo " DONE"
  fi
  SECONDS=0
  echo -n "Waiting for ${pod_prefix} pod becoming ready ..."
  while ! ct_os_check_pod_readiness "${pod_prefix}" "true" ; do
    echo -n "."
    if [ "${SECONDS}" -gt "${timeout}" ]; then
      echo " FAIL";
      ct_os_print_logs || :
      ct_os_get_sti_build_logs "${pod_prefix}" || :
      return 1
    fi
    sleep 3
  done
  echo " DONE"
}

# ct_os_wait_rc_ready POD_PREFIX TIMEOUT
# --------------------
# Wait maximum [timeout] for the rc having desired number of replicas ready.
# Arguments: pod_prefix - prefix of the replication controller
# Arguments: timeout - how many seconds to wait seconds
function ct_os_wait_rc_ready() {
  local pod_prefix="${1}" ; shift
  local timeout="${1}" ; shift
  SECONDS=0
  echo -n "Waiting for ${pod_prefix} having desired numbers of replicas ..."
  while ! test "$( (oc get --no-headers statefulsets; oc get --no-headers rc) 2>/dev/null \
                 | grep "^${pod_prefix}" | awk '$2==$3 {print "ready"}')" == "ready" ; do
    echo -n "."
    if [ "${SECONDS}" -gt "${timeout}" ]; then
      echo " FAIL";
      ct_os_print_logs || :
      ct_os_get_sti_build_logs "${pod_prefix}" || :
      return 1
    fi
    sleep 3
  done
  echo " DONE"
}

# ct_os_deploy_pure_image IMAGE [ENV_PARAMS, ...]
# --------------------
# Runs [image] in the openshift and optionally specifies env_params
# as environment variables to the image.
# Arguments: image - prefix or whole ID of the pod to run the cmd in
# Arguments: env_params - environment variables parameters for the images.
function ct_os_deploy_pure_image() {
  local image="${1}" ; shift
  # ignore error exit code, because oc new-app returns error when image exists
  oc new-app "${image}" "$@" || :
  # let openshift cluster to sync to avoid some race condition errors
  sleep 3
}

# ct_os_deploy_s2i_image IMAGE APP [ENV_PARAMS, ... ]
# --------------------
# Runs [image] and [app] in the openshift and optionally specifies env_params
# as environment variables to the image.
# Arguments: image - prefix or whole ID of the pod to run the cmd in
# Arguments: app - url or local path to git repo with the application sources.
# Arguments: env_params - environment variables parameters for the images.
function ct_os_deploy_s2i_image() {
  local image="${1}" ; shift
  local app="${1}" ; shift
  # ignore error exit code, because oc new-app returns error when image exists
  oc new-app "${image}~${app}" --strategy=source "$@" || :

  # let openshift cluster to sync to avoid some race condition errors
  sleep 3
}

# ct_os_deploy_template_image TEMPLATE [ENV_PARAMS, ...]
# --------------------
# Runs template in the openshift and optionally gives env_params to use
# specific values in the template.
# Arguments: template - prefix or whole ID of the pod to run the cmd in
# Arguments: env_params - environment variables parameters for the template.
# Example usage: ct_os_deploy_template_image mariadb-ephemeral-template.yaml \
#                                            DATABASE_SERVICE_NAME=mysql-80-c9s \
#                                            DATABASE_IMAGE=mysql-80-c9s \
#                                            MYSQL_USER=testu \
#                                            MYSQL_PASSWORD=testp \
#                                            MYSQL_DATABASE=testdb
function ct_os_deploy_template_image() {
  local template="${1}" ; shift
  oc process -f "${template}" "$@" | oc create -f -
  # let openshift cluster to sync to avoid some race condition errors
  sleep 3
}

# _ct_os_get_uniq_project_name
# --------------------
# Returns a uniq name of the OpenShift project.
function _ct_os_get_uniq_project_name() {
  local r
  while true ; do
    r=${RANDOM}
    mkdir /var/tmp/sclorg-test-${r} &>/dev/null && echo sclorg-test-${r} && break
  done
}

# ct_os_new_project [PROJECT]
# --------------------
# Creates a new project in the openshfit using 'os' command.
# Arguments: project - project name, uses a new random name if omitted
# Expects 'os' command that is properly logged in to the OpenShift cluster.
# Not using mktemp, because we cannot use uppercase characters.
# The OPENSHIFT_CLUSTER_PULLSECRET_PATH environment variable can be set
# to contain a path to a k8s secret definition which will be used
# to authenticate to image registries.
# shellcheck disable=SC2120
function ct_os_new_project() {
  if [ "${CVP:-0}" -eq "1" ]; then
    echo "Testing in CVP environment. No need to create OpenShift project. This is done by CVP pipeline"
    return
  fi
  if [ "${CT_SKIP_NEW_PROJECT:-false}" == 'true' ] ; then
    echo "Creating project skipped."
    return
  fi
  local project_name="${1:-$(_ct_os_get_uniq_project_name)}" ; shift || :
  oc new-project "${project_name}"
  # let openshift cluster to sync to avoid some race condition errors
  sleep 3
  if test -n "${OPENSHIFT_CLUSTER_PULLSECRET_PATH:-}" -a -e "${OPENSHIFT_CLUSTER_PULLSECRET_PATH:-}"; then
    oc create -f "$OPENSHIFT_CLUSTER_PULLSECRET_PATH"
    # add registry pullsecret to the serviceaccount if provided
    secret_name=$(grep '^\s*name:' "$OPENSHIFT_CLUSTER_PULLSECRET_PATH" | awk '{ print $2 }')
    oc secrets link --for=pull default "$secret_name"
  fi
}

# ct_os_delete_project [PROJECT]
# --------------------
# Deletes the specified project in the openshfit
# Arguments: project - project name, uses the current project if omitted
# shellcheck disable=SC2120
function ct_os_delete_project() {
  if [ "${CT_SKIP_NEW_PROJECT:-false}" == 'true' ] || [ "${CVP:-0}" -eq "1" ]; then
    echo "Deleting project skipped, cleaning objects only."
    # when not having enough privileges (remote cluster), it might fail and
    # it is not a big problem, so ignore failure in this case
    ct_delete_all_objects || :
    return
  fi
  local project_name="${1:-$(oc project -q)}" ; shift || :
  if oc delete project "${project_name}" ; then
    echo "Project ${project_name} was deleted properly"
  else
    echo "Project ${project_name} was not delete properly. But it does not block CI."
  fi

}

# ct_delete_all_objects
# -----------------
# Deletes all objects within the project.
# Handy when we have one project and want to run more tests.
function ct_delete_all_objects() {
  local objects="bc builds dc is isimage istag po rc routes svc"
  if [ "${CVP:-0}" -eq "1" ]; then
    echo "Testing in CVP environment. No need to delete isimage and istag in OpenShift project. This is done by CVP pipeline"
    objects="bc builds dc po pvc rc routes"
  fi
  for x in $objects; do
    echo "oc gets info about $x"
    oc get "$x"
    echo "oc deletes $x with --all --force --grace-period=0"
    oc delete "$x" --all --force --grace-period=0
  done
  # for some objects it takes longer to be really deleted, so a dummy sleep
  # to avoid some races when other test can see not-yet-deleted objects and can fail
  sleep 10
}

# ct_os_docker_login_v4
# --------------------
# Logs in into docker daemon
# Uses global REGISRTY_ADDRESS environment variable for arbitrary registry address.
# Does not do anything if REGISTRY_ADDRESS is set.
function ct_os_docker_login_v4() {
  OCP4_REGISTER=$(oc get route default-route -n openshift-image-registry --template='{{ .spec.host }}')
  echo "OCP4 loging address is $OCP4_REGISTER."
  if [ -z "${OCP4_REGISTER}" ]; then
    echo "!!!OpenShift 4 registry address not found. This is an error. Check OpenShift 4 cluster!!!"
    return 1
  fi

  if docker login -u kubeadmin -p "$(oc whoami -t)" "${OCP4_REGISTER}"; then
    echo "Login to $OCP4_REGISTER was successfully."
    return 0
  fi
  return 1
}

# ct_os_upload_image IMAGE [IMAGESTREAM]
# --------------------
# Uploads image from local registry to the OpenShift internal registry.
# Arguments: image - image name to upload
# Arguments: imagestream - name and tag to use for the internal registry.
#                          In the format of name:tag ($image_name:latest by default)
# Uses global REGISRTY_ADDRESS environment variable for arbitrary registry address.
function ct_os_upload_image() {
  local input_name="${1}" ; shift
  local image_name=${1}
  local output_name
  local source_name

  source_name="${input_name}"
  # Variable OCP4_REGISTER is set in function ct_os_docker_login_v4
  if ! ct_os_docker_login_v4; then
    return 1
  fi
  output_name="$OCP4_REGISTER/$namespace/$image_name"

  docker tag "${source_name}" "${output_name}"
  docker push "${output_name}"
}

# ct_os_is_tag_exists IS_NAME TAG
# --------------------
# Checks whether the specified tag exists for an image stream
# Arguments: is_name - name of the image stream
# Arguments: tag - name of the tag (usually version)
function ct_os_is_tag_exists() {
  local is_name=$1 ; shift
  local tag=$1 ; shift
  oc get is "${is_name}" -n openshift -o=jsonpath='{.spec.tags[*].name}' | grep -qw "${tag}"
}

# ct_os_template_exists T_NAME
# --------------------
# Checks whether the specified template exists for an image stream
# Arguments: t_name - template name of the image stream
function ct_os_template_exists() {
  local t_name=$1 ; shift
  oc get templates -n openshift | grep -q "^${t_name}\s"
}

# ct_os_cluster_running
# --------------------
# Returns 0 if oc cluster is running
function ct_os_cluster_running() {
  oc cluster status &>/dev/null
}

# ct_os_logged_in
# ---------------
# Returns 0 if logged in to a cluster (remote or local)
function ct_os_logged_in() {
  oc whoami >/dev/null
}

# ct_os_test_s2i_app_func IMAGE APP CONTEXT_DIR CHECK_CMD [OC_ARGS]
# --------------------
# Runs [image] and [app] in the openshift and optionally specifies env_params
# as environment variables to the image. Then check the container by arbitrary
# function given as argument (such an argument may include <IP> string,
# that will be replaced with actual IP).
# Arguments: image - prefix or whole ID of the pod to run the cmd in  (compulsory)
# Arguments: app - url or local path to git repo with the application sources  (compulsory)
# Arguments: context_dir - sub-directory inside the repository with the application sources (compulsory)
# Arguments: check_command - CMD line that checks whether the container works (compulsory; '<IP>' will be replaced with actual IP)
# Arguments: oc_args - all other arguments are used as additional parameters for the `oc new-app`
#            command, typically environment variables (optional)
function ct_os_test_s2i_app_func() {
  local image_name=${1}
  local app=${2}
  local context_dir=${3}
  local check_command=${4}
  local oc_args=${5:-}
  local image_name_no_namespace=${image_name##*/}
  local service_name="${image_name_no_namespace%%:*}-testing"
  local namespace

  if [ $# -lt 4 ] || [ -z "${1}" ] || [ -z "${2}" ] || [ -z "${3}" ] || [ -z "${4}" ]; then
    echo "ERROR: ct_os_test_s2i_app_func() requires at least 4 arguments that cannot be emtpy." >&2
    return 1
  fi

  # shellcheck disable=SC2119
  ct_os_new_project

  namespace=${CT_NAMESPACE:-"$(oc project -q)"}
  local image_tagged="${image_name_no_namespace%:*}:${VERSION}"

  if [ "${CVP:-0}" -eq "0" ]; then
    echo "Uploading image ${image_name} as ${image_tagged} into OpenShift internal registry."
    ct_os_upload_image "${image_name}" "${image_tagged}"
  else
    echo "Testing image ${image_name} in CVP pipeline."
  fi

  local app_param="${app}"
  if [ -d "${app}" ] ; then
    # for local directory, we need to copy the content, otherwise too smart os command
    # pulls the git remote repository instead
    app_param=$(ct_obtain_input "${app}")
  fi

  # shellcheck disable=SC2086
  ct_os_deploy_s2i_image "${image_tagged}" "${app_param}" \
                          --context-dir="${context_dir}" \
                          --name "${service_name}" \
                          ${oc_args}

  if [ -d "${app}" ] ; then
    # in order to avoid weird race seen sometimes, let's wait shortly
    # before starting the build explicitly
    sleep 5
    oc start-build "${service_name}" --from-dir="${app_param}"
  fi

  ct_os_wait_pod_ready "${service_name}" 300

  local ip
  local check_command_exp
  local image_id

  # get image ID from the deployment config
  image_id=$(oc get "deploymentconfig.apps.openshift.io/${service_name}" -o custom-columns=IMAGE:.spec.template.spec.containers[*].image | tail -n 1)

  ip=$(ct_os_get_service_ip "${service_name}")
  # shellcheck disable=SC2001
  check_command_exp=$(echo "$check_command" | sed -e "s/<IP>/$ip/g" -e "s|<SAME_IMAGE>|${image_id}|g")

  echo "  Checking APP using $check_command_exp ..."
  local result=0
  eval "$check_command_exp" || result=1

  ct_os_service_image_info "${service_name}"

  if [ $result -eq 0 ] ; then
    echo "  Check passed."
  else
    echo "  Check failed."
  fi

  # shellcheck disable=SC2119
  ct_os_delete_project
  return $result
}

# ct_os_test_s2i_app IMAGE APP CONTEXT_DIR EXPECTED_OUTPUT [PORT, PROTOCOL, RESPONSE_CODE, OC_ARGS, ... ]
# --------------------
# Runs [image] and [app] in the openshift and optionally specifies env_params
# as environment variables to the image. Then check the http response.
# Arguments: image - prefix or whole ID of the pod to run the cmd in (compulsory)
# Arguments: app - url or local path to git repo with the application sources (compulsory)
# Arguments: context_dir - sub-directory inside the repository with the application sources (compulsory)
# Arguments: expected_output - PCRE regular expression that must match the response body (compulsory)
# Arguments: port - which port to use (optional; default: 8080)
# Arguments: protocol - which protocol to use (optional; default: http)
# Arguments: response_code - what http response code to expect (optional; default: 200)
# Arguments: oc_args - all other arguments are used as additional parameters for the `oc new-app`
#            command, typically environment variables (optional)
function ct_os_test_s2i_app() {
  local image_name=${1}
  local app=${2}
  local context_dir=${3}
  local expected_output=${4}
  local port=${5:-8080}
  local protocol=${6:-http}
  local response_code=${7:-200}
  local oc_args=${8:-}

  if [ $# -lt 4 ] || [ -z "${1}" ] || [ -z "${2}" ] || [ -z "${3}" ] || [ -z "${4}" ]; then
    echo "ERROR: ct_os_test_s2i_app() requires at least 4 arguments that cannot be emtpy." >&2
    return 1
  fi

  ct_os_test_s2i_app_func "${image_name}" \
                          "${app}" \
                          "${context_dir}" \
                          "ct_os_test_response_internal '${protocol}://<IP>:${port}' '${response_code}' '${expected_output}'" \
                          "${oc_args}"
}

# ct_os_test_template_app_func IMAGE APP IMAGE_IN_TEMPLATE CHECK_CMD [OC_ARGS]
# --------------------
# Runs [image] and [app] in the openshift and optionally specifies env_params
# as environment variables to the image. Then check the container by arbitrary
# function given as argument (such an argument may include <IP> string,
# that will be replaced with actual IP).
# Arguments: image_name - prefix or whole ID of the pod to run the cmd in  (compulsory)
# Arguments: template - url or local path to a template to use (compulsory)
# Arguments: name_in_template - image name used in the template
# Arguments: check_command - CMD line that checks whether the container works (compulsory; '<IP>' will be replaced with actual IP)
# Arguments: oc_args - all other arguments are used as additional parameters for the `oc new-app`
#            command, typically environment variables (optional)
# Arguments: other_images - some templates need other image to be pushed into the OpenShift registry,
#            specify them in this parameter as "<image>|<tag>", where "<image>" is a full image name
#            (including registry if needed) and "<tag>" is a tag under which the image should be available
#            in the OpenShift registry.
function ct_os_test_template_app_func() {
  local image_name=${1}
  local template=${2}
  local name_in_template=${3}
  local check_command=${4}
  local oc_args=${5:-}
  local other_images=${6:-}

  if [ $# -lt 4 ] || [ -z "${1}" ] || [ -z "${2}" ] || [ -z "${3}" ] || [ -z "${4}" ]; then
    echo "ERROR: ct_os_test_template_app_func() requires at least 4 arguments that cannot be emtpy." >&2
    return 1
  fi

  local service_name="${name_in_template}-testing"
  local image_tagged="${name_in_template}:${VERSION}"
  local namespace

  # shellcheck disable=SC2119
  ct_os_new_project

  namespace=${CT_NAMESPACE:-"$(oc project -q)"}
  # Upload main image is already done by CVP pipeline. No need to do it twice.
  if [ "${CVP:-0}" -eq "0" ]; then
    # Create a specific imagestream tag for the image so that oc cannot use anything else
    echo "Uploading image ${image_name} as ${image_tagged} into OpenShift internal registry."
    ct_os_upload_image "${image_name}" "${image_tagged}"
  else
    echo "Import is already done by CVP pipeline."
  fi
  # Upload main image is already done by CVP pipeline. No need to do it twice.
  if [ "${CVP:-0}" -eq "0" ]; then
    # Other images are not uploaded by CVP pipeline. We need to do it.
    # upload also other images, that template might need (list of pairs in the format <image>|<tag>
    local image_tag_a
    local i_t
    for i_t in ${other_images} ; do
      echo "${i_t}"
      IFS='|' read -ra image_tag_a <<< "${i_t}"
      if [[ "$(docker images -q "$image_name" 2>/dev/null)" == "" ]]; then
        echo "ERROR: Image $image_name is not pulled yet."
        docker images
        echo "Add to the beginning of scripts run-openshift-remote-cluster and run-openshift row"
        echo "'ct_pull_image $image_name true'."
        exit 1
      fi

        echo "Uploading image ${image_tag_a[0]} as ${image_tag_a[1]} into OpenShift internal registry."
        ct_os_upload_image "${image_tag_a[0]}" "${image_tag_a[1]}"
    done
  fi

  # get the template file from remote or local location; if not found, it is
  # considered an internal template name, like 'mysql', so use the name
  # explicitly
  local local_template

  local_template=$(ct_obtain_input "${template}" 2>/dev/null || echo "--template=${template}")

  echo "Creating a new-app with name ${name_in_template} in namespace ${namespace} with args ${oc_args}."
  # shellcheck disable=SC2086
  oc new-app "${local_template}" \
             --name "${name_in_template}" \
             -p NAMESPACE="${namespace}" \
             ${oc_args}

  ct_os_wait_pod_ready "${service_name}" 300

  local ip
  local check_command_exp
  local image_id

  # get image ID from the deployment config
  image_id=$(oc get "deploymentconfig.apps.openshift.io/${service_name}" -o custom-columns=IMAGE:.spec.template.spec.containers[*].image | tail -n 1)

  ip=$(ct_os_get_service_ip "${service_name}")
  # shellcheck disable=SC2001
  check_command_exp=$(echo "$check_command" | sed -e "s/<IP>/$ip/g" -e "s|<SAME_IMAGE>|${image_id}|g")

  echo "  Checking APP using $check_command_exp ..."
  local result=0
  eval "$check_command_exp" || result=1

  ct_os_service_image_info "${service_name}"

  if [ $result -eq 0 ] ; then
    echo "  Check passed."
  else
    echo "  Check failed."
  fi

  # shellcheck disable=SC2119
  ct_os_delete_project
  return $result
}

# params:
# ct_os_test_template_app IMAGE APP IMAGE_IN_TEMPLATE EXPECTED_OUTPUT [PORT, PROTOCOL, RESPONSE_CODE, OC_ARGS, ... ]
# --------------------
# Runs [image] and [app] in the openshift and optionally specifies env_params
# as environment variables to the image. Then check the http response.
# Arguments: image_name - prefix or whole ID of the pod to run the cmd in (compulsory)
# Arguments: template - url or local path to a template to use (compulsory)
# Arguments: name_in_template - image name used in the template
# Arguments: expected_output - PCRE regular expression that must match the response body (compulsory)
# Arguments: port - which port to use (optional; default: 8080)
# Arguments: protocol - which protocol to use (optional; default: http)
# Arguments: response_code - what http response code to expect (optional; default: 200)
# Arguments: oc_args - all other arguments are used as additional parameters for the `oc new-app`
#            command, typically environment variables (optional)
# Arguments: other_images - some templates need other image to be pushed into the OpenShift registry,
#            specify them in this parameter as "<image>|<tag>", where "<image>" is a full image name
#            (including registry if needed) and "<tag>" is a tag under which the image should be available
#            in the OpenShift registry.
function ct_os_test_template_app() {
  local image_name=${1}
  local template=${2}
  local name_in_template=${3}
  local expected_output=${4}
  local port=${5:-8080}
  local protocol=${6:-http}
  local response_code=${7:-200}
  local oc_args=${8:-}
  local other_images=${9:-}

  if [ $# -lt 4 ] || [ -z "${1}" ] || [ -z "${2}" ] || [ -z "${3}" ] || [ -z "${4}" ]; then
    echo "ERROR: ct_os_test_template_app() requires at least 4 arguments that cannot be emtpy." >&2
    return 1
  fi

  ct_os_test_template_app_func "${image_name}" \
                               "${template}" \
                               "${name_in_template}" \
                               "ct_os_test_response_internal '${protocol}://<IP>:${port}' '${response_code}' '${expected_output}'" \
                               "${oc_args}" \
                               "${other_images}"
}

# ct_os_test_image_update IMAGE_NAME OLD_IMAGE ISTAG CHECK_FUNCTION OC_ARGS
# --------------------
# Runs an image update test with [image] uploaded to [is] imagestream
# and checks the services using an arbitrary function provided in [check_function].
# Arguments: image_name - prefix or whole ID of the pod to run the cmd in (compulsory)
# Arguments: old_image - valid name of the image from the registry
# Arguments: istag - imagestream to upload the images into (compulsory)
# Arguments: check_function - command to be run to check functionality of created services (compulsory)
# Arguments: oc_args - arguments to use during oc new-app (compulsory)
ct_os_test_image_update() {
  local image_name=$1; shift
  local old_image=$1; shift
  local istag=$1; shift
  local check_function=$1; shift
  local ip="" check_command_exp=""
  local image_name_no_namespace=${image_name##*/}
  local service_name="${image_name_no_namespace%%:*}-testing"

  echo "Running image update test for: $image_name"
  # shellcheck disable=SC2119
  ct_os_new_project

  # Get current image from repository and create an imagestream
  docker pull "$old_image:latest" 2>/dev/null
  ct_os_upload_image "$old_image" "$istag"

  # Setup example application with curent image
  oc new-app "$@" --name "$service_name"
  ct_os_wait_pod_ready "$service_name" 60

  # Check application output
  ip=$(ct_os_get_service_ip "$service_name")
  check_command_exp=${check_function//<IP>/$ip}
  ct_assert_cmd_success "$check_command_exp"

  # Tag built image into the imagestream and wait for rebuild
  ct_os_upload_image "$image_name" "$istag"
  ct_os_wait_pod_ready "${service_name}-2" 60

  # Check application output
  ip=$(ct_os_get_service_ip "$service_name")
  check_command_exp=${check_function//<IP>/$ip}
  ct_assert_cmd_success "$check_command_exp"

  # shellcheck disable=SC2119
  ct_os_delete_project
}

# ct_os_deploy_cmd_image IMAGE_NAME
# --------------------
# Runs a special command pod, a pod that does nothing, but includes utilities for testing.
# A typical usage is a mysql pod that includes mysql commandline, that we need for testing.
# Running commands inside this command pod is done via ct_os_cmd_image_run function.
# The pod is not run again if already running.
# Arguments: image_name - image to be used as a command pod
function ct_os_deploy_cmd_image() {
  local image_name=${1}
  oc get pod command-app &>/dev/null && echo "command POD already running" && return 0
  echo "command POD not running yet, will start one called command-app ${image_name}"
  oc create -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: command-app
spec:
  containers:
  - name: command-container
    image: "${image_name}"
    command: ["sleep"]
    args: ["3h"]
  restartPolicy: OnFailure
EOF

  SECONDS=0
  echo -n "Waiting for command POD ."
  while [ $SECONDS -lt 180 ] ; do
    # Let's show status of all pods. Not only command-container for tracking issues
    oc get pods
    # shellcheck disable=SC2016
    sout="$(ct_os_cmd_image_run 'echo $((11*11))' 2>/dev/null)"
    # shellcheck disable=SC2015
    grep -q '^121$' <<< "$sout" && echo "DONE" && return 0 || :
    sleep 3
    echo -n "."
  done
  echo "FAIL"
  return 1
}

# ct_os_cmd_image_run CMD [ ARG ... ]
# --------------------
# Runs a command CMD inside a special command pod
# Arguments: cmd - shell command with args to run in a pod
function ct_os_cmd_image_run() {
  oc exec command-app -- bash -c "$@"
}

# ct_os_test_response_internal
# ----------------
# Perform GET request to the application container, checks output with
# a reg-exp and HTTP response code.
# That all is done inside an image in the cluster, so the function is used
# typically in clusters that are not accessible outside.
# The interanal image is a python image that should include the most of the useful commands.
# The check is repeated until timeout.
# Argument: url - request URL path
# Argument: expected_code - expected HTTP response code
# Argument: body_regexp - PCRE regular expression that must match the response body
# Argument: max_attempts - Optional number of attempts (default: 20), three seconds sleep between
# Argument: ignore_error_attempts - Optional number of attempts when we ignore error output (default: 10)
ct_os_test_response_internal() {
  local url="$1"
  local expected_code="$2"
  local body_regexp="$3"
  local max_attempts=${4:-20}
  local ignore_error_attempts=${5:-10}

  : "  Testing the HTTP(S) response for <${url}>"
  local sleep_time=3
  local attempt=1
  local result=1
  local status
  local response_code
  local response_file
  local util_image_name='registry.access.redhat.com/ubi7/ubi'

  response_file=$(mktemp /tmp/ct_test_response_XXXXXX)
  ct_os_deploy_cmd_image "${util_image_name}"

  while [ "${attempt}" -le "${max_attempts}" ]; do
    ct_os_cmd_image_run "curl --connect-timeout 10 -s -w '%{http_code}' '${url}'" >"${response_file}" && status=0 || status=1
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

# ct_os_get_image_from_pod
# ------------------------
# Print image identifier from an existing pod to stdout
# Argument: pod_prefix - prefix or full name of the pod to get image from
ct_os_get_image_from_pod() {
  local pod_prefix=$1 ; shift
  local pod_name
  pod_name=$(ct_os_get_pod_name "$pod_prefix")
  oc get "po/${pod_name}" -o yaml | sed -ne 's/^\s*image:\s*\(.*\)\s*$/\1/ p' | head -1
}

# ct_os_check_cmd_internal
# ----------------
# Runs a specified command, checks exit code and compares the output with expected regexp.
# That all is done inside an image in the cluster, so the function is used
# typically in clusters that are not accessible outside.
# The check is repeated until timeout.
# Argument: util_image_name - name of the image in the cluster that is used for running the cmd
# Argument: service_name - kubernetes' service name to work with (IP address is taken from this one)
# Argument: check_command - command that is run within the util_image_name container
# Argument: expected_content_match - regexp that must be in the output (use .* to ignore check)
# Argument: timeout - number of seconds to wait till the check succeeds
function ct_os_check_cmd_internal() {
  local util_image_name=$1 ; shift
  local service_name=$1 ; shift
  local check_command=$1 ; shift
  local expected_content_match=${1:-.*} ; shift
  local timeout=${1:-60} ; shift || :

  : "  Service ${service_name} check ..."

  local output
  local ret
  local ip
  local check_command_exp

  ip=$(ct_os_get_service_ip "${service_name}")
  # shellcheck disable=SC2001
  check_command_exp=$(echo "$check_command" | sed -e "s/<IP>/$ip/g")

  ct_os_deploy_cmd_image "${util_image_name}"
  SECONDS=0

  echo -n "Waiting for ${service_name} service becoming ready ..."
  while true ; do
    output=$(ct_os_cmd_image_run "$check_command_exp")
    ret=$?
    echo "${output}" | grep -qe "${expected_content_match}" || ret=1
    if [ ${ret} -eq 0 ] ; then
      echo " PASS"
      return 0
    fi
    echo -n "."
    [ ${SECONDS} -gt "${timeout}" ] && break
    sleep 3
  done
  echo " FAIL"
  return 1
}

# ct_os_test_image_stream_template IMAGE_STREAM_FILE TEMPLATE_FILE SERVICE NAME [TEMPLATE_PARAMS]
# ------------------------
# Creates an image stream and deploys a specified template. Then checks that a pod runs.
# Argument: image_stream_file - local or remote file with the image stream definition
# Argument: template_file - local file name with a template
# Argument: service_name - how the pod will be named (prefix)
# Argument: template_params (optional) - parameters for the template, like image stream version
function ct_os_test_image_stream_template() {
  local image_stream_file=${1}
  local template_file=${2}
  local service_name=${3}
  local template_params=${4:-}
  local local_image_stream_file
  local local_template_file

  if [ $# -lt 3 ] || [ -z "${1}" ] || [ -z "${2}" ] || [ -z "${3}" ]; then
    echo "ERROR: ct_os_test_image_stream() requires at least 3 arguments that cannot be empty." >&2
    return 1
  fi

  echo "Running image stream test for stream ${image_stream_file} and template ${template_file}"
  # shellcheck disable=SC2119
  ct_os_new_project

  local_image_stream_file=$(ct_obtain_input "${image_stream_file}")
  local_template_file=$(ct_obtain_input "${template_file}")
  oc create -f "${local_image_stream_file}"

  # shellcheck disable=SC2086
  if ! ct_os_deploy_template_image "${local_template_file}" -p NAMESPACE="${CT_NAMESPACE:-$(oc project -q)}" ${template_params} ; then
    echo "ERROR: ${template_file} could not be loaded"
    return 1
    # Deliberately not runnig ct_os_delete_project here because user either
    # might want to investigate or the cleanup is done with the cleanup trap.
    # Most functions depend on the set -e anyway at this point.
  fi
  ct_os_wait_pod_ready "${service_name}" 120
  result=$?

  # shellcheck disable=SC2119
  ct_os_delete_project
  return $result
}

# ct_os_wait_stream_ready IMAGE_STREAM_FILE NAMESPACE [ TIMEOUT ]
# ------------------------
# Waits max timeout seconds till a [stream] is available in the [namespace].
# Arguments: image_stream - stream name (usuallly <image>:<version>)
# Arguments: namespace - namespace name
# Arguments: timeout - how many seconds to wait
function ct_os_wait_stream_ready() {
  local image_stream=${1}
  local namespace=${2}
  local timeout=${3:-60}
  # It takes some time for the first time before the image is pulled in
  SECONDS=0
  echo -n "Waiting for ${namespace}/${image_stream} to become available ..."
  while ! oc get -n "${namespace}" istag "${image_stream}" &>/dev/null; do
    if [ "$SECONDS" -gt "${timeout}" ] ; then
      echo "FAIL: ${namespace}/${image_stream} not available after ${timeout}s:"
      echo "oc get -n ${namespace} istag ${image_stream}"
      oc get -n "${namespace}" istag "${image_stream}"
      return 1
    fi
    sleep 3
    echo -n .
  done
  echo " DONE"
}

# ct_os_test_image_stream_s2i IMAGE_STREAM_FILE IMAGE_NAME APP CONTEXT_DIR EXPECTED_OUTPUT [PORT, PROTOCOL, RESPONSE_CODE, OC_ARGS, ... ]
# --------------------
# Check the imagestream with an s2i app check. First it imports the given image stream, then
# it runs [image] and [app] in the openshift and optionally specifies env_params
# as environment variables to the image. Then check the http response.
# Argument: image_stream_file - local or remote file with the image stream definition
# Argument: image_name - container image we test (or name of the existing image stream in <name>:<version> format)
# Argument: app - url or local path to git repo with the application sources (compulsory)
# Argument: context_dir - sub-directory inside the repository with the application sources (compulsory)
# Argument: expected_output - PCRE regular expression that must match the response body (compulsory)
# Argument: port - which port to use (optional; default: 8080)
# Argument: protocol - which protocol to use (optional; default: http)
# Argument: response_code - what http response code to expect (optional; default: 200)
# Argument: oc_args - all other arguments are used as additional parameters for the `oc new-app`
#            command, typically environment variables (optional)
function ct_os_test_image_stream_s2i() {
  local image_stream_file=${1}
  local image_name=${2}
  local app=${3}
  local context_dir=${4}
  local expected_output=${5}
  local port=${6:-8080}
  local protocol=${7:-http}
  local response_code=${8:-200}
  local oc_args=${9:-}
  local result
  local local_image_stream_file

  echo "Running image stream test for stream ${image_stream_file} and application ${app} with context ${context_dir}"

  # shellcheck disable=SC2119
  ct_os_new_project

  local_image_stream_file=$(ct_obtain_input "${image_stream_file}")
  oc create -f "${local_image_stream_file}"

  # ct_os_test_s2i_app creates a new project, but we already need
  # it before for the image stream import, so tell it to skip this time
  CT_SKIP_NEW_PROJECT=true \
  ct_os_test_s2i_app "${IMAGE_NAME}" "${app}" "${context_dir}" "${expected_output}" \
                     "${port}" "${protocol}" "${response_code}" "${oc_args}"
  result=$?

  # shellcheck disable=SC2119
  CT_SKIP_NEW_PROJECT=false
  ct_os_delete_project

  return $result
}

# ct_os_test_image_stream_quickstart IMAGE_STREAM_FILE TEMPLATE IMAGE_NAME NAME_IN_TEMPLATE EXPECTED_OUTPUT [PORT, PROTOCOL, RESPONSE_CODE, OC_ARGS, OTHER_IMAGES ]
# --------------------
# Check the imagestream with an s2i app check. First it imports the given image stream, then
# it runs [image] and [app] in the openshift and optionally specifies env_params
# as environment variables to the image. Then check the http response.
# Argument: image_stream_file - local or remote file with the image stream definition
# Argument: template_file - local file name with a template
# Argument: image_name - container image we test (or name of the existing image stream in <name>:<version> format)
# Argument: name_in_template - image name used in the template
# Argument: expected_output - PCRE regular expression that must match the response body (compulsory)
# Argument: port - which port to use (optional; default: 8080)
# Argument: protocol - which protocol to use (optional; default: http)
# Argument: response_code - what http response code to expect (optional; default: 200)
# Argument: oc_args - all other arguments are used as additional parameters for the `oc new-app`
#            command, typically environment variables (optional)
# Argument: other_images - some templates need other image to be pushed into the OpenShift registry,
#            specify them in this parameter as "<image>|<tag>", where "<image>" is a full image name
#            (including registry if needed) and "<tag>" is a tag under which the image should be available
#            in the OpenShift registry.
function ct_os_test_image_stream_quickstart() {
  local image_stream_file=${1}
  local template_file=${2}
  local image_name=${3}
  local name_in_template=${4}
  local expected_output=${5}
  local port=${6:-8080}
  local protocol=${7:-http}
  local response_code=${8:-200}
  local oc_args=${9:-}
  local other_images=${10:-}
  local result
  local local_image_stream_file
  local local_template_file

  echo "Running image stream test for stream ${image_stream_file} and quickstart template ${template_file}"
  echo "Image name is ${IMAGE_NAME}"
  # shellcheck disable=SC2119
  ct_os_new_project

  local_image_stream_file=$(ct_obtain_input "${image_stream_file}")
  local_template_file=$(ct_obtain_input "${template_file}")
  # ct_os_test_template_app creates a new project, but we already need
  # it before for the image stream import, so tell it to skip this time
  namespace=${CT_NAMESPACE:-"$(oc project -q)"}

  # Add namespace into openshift arguments
  if [[ $oc_args != *"NAMESPACE"* ]]; then
    oc_args="${oc_args} -p NAMESPACE=${namespace}"
  fi
  oc create -f "${local_image_stream_file}"

  # In case we are testing on OpenShift 4 export variable for mirror image
  # which means, that image is going to be mirrored from an internal registry into OpenShift 4
  if [ "${CT_EXTERNAL_REGISTRY:-false}" == 'true' ]; then
    export CT_TAG_IMAGE=true
  fi
  # ct_os_test_template_app creates a new project, but we already need
  # it before for the image stream import, so tell it to skip this time

  CT_SKIP_NEW_PROJECT=true \
  ct_os_test_template_app "${image_name}" \
                          "${local_template_file}" \
                          "${name_in_template}" \
                          "${expected_output}" \
                          "${port}" "${protocol}" "${response_code}" "${oc_args}" "${other_images}"

  result=$?

  # shellcheck disable=SC2119
  CT_SKIP_NEW_PROJECT=false
  ct_os_delete_project

  return $result
}

# ct_os_service_image_info SERVICE_NAME
# --------------------
# Shows information about the image used by a specified service.
# Argument: service_name - Service name (uesd for deployment config)
function ct_os_service_image_info() {
  local service_name=$1
  local image_id
  local namespace

  # get image ID from the deployment config
  image_id=$(oc get "deploymentconfig.apps.openshift.io/${service_name}" -o custom-columns=IMAGE:.spec.template.spec.containers[*].image | tail -n 1)
  namespace=${CT_NAMESPACE:-"$(oc project -q)"}

  echo "  Information about the image we work with:"
  oc get deploymentconfig.apps.openshift.io/"${service_name}" -o yaml | grep lastTriggeredImage
  # for s2i builds, the resulting image is actually in the current namespace,
  # so if the specified namespace does not succeed, try the current namespace
  oc get isimage -n "${namespace}" "${image_id##*/}" -o yaml || oc get isimage "${image_id##*/}" -o yaml
}
# vim: set tabstop=2:shiftwidth=2:expandtab:
