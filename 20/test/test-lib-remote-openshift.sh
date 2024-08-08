# shellcheck disable=SC2148
if [ -z "${sourced_test_lib_remote_openshift:-}" ]; then
  sourced_test_lib_remote_openshift=1
else
  return 0
fi

# shellcheck shell=bash
# some functions are used from test-lib.sh, that is usually in the same dir
# shellcheck source=/dev/null
source "$(dirname "${BASH_SOURCE[0]}")"/test-lib.sh

# this should be returned when something related to the openshift cluster
# goes wrong during the test pipeline
# shellcheck disable=SC2034
readonly OC_ERR=11

# Set of functions for testing docker images in OpenShift using 'oc' command

# A variable containing the overall test result
#   TESTSUITE_RESULT=0
# And the following trap must be set, in the beginning of the test script:
#   trap ct_os_cleanup EXIT SIGINT

# ct_os_set_path_oc_4 OC_VERSION
# --------------------
# This is a trick that helps using correct version 4 of the `oc`:
# The input is version of the openshift in format 4.4 etc.
# If the currently available version of oc is not of this version,
# it first takes a look into /usr/local/oc-<ver>/bin directory,

# Arguments: oc_version - X.Y part of the version of OSE (e.g. 4.4)
function ct_os_set_path_oc_4() {
    echo "Setting OCP4 client"
    local oc_version=$1
    local installed_oc_path="/usr/local/oc-v${oc_version}/bin"
    echo "PATH ${installed_oc_path}"
    if [ -x "${installed_oc_path}/oc" ] ; then
        oc_path="${installed_oc_path}"
        echo "Binary oc found in ${installed_oc_path}" >&2
    else
       echo "OpenShift Client binary on path ${installed_oc_path} not found"
       return 1
    fi
    export PATH="${oc_path}:${PATH}"
}

# ct_os_prepare_ocp4
# ------------------
# Prepares environment for testing images in OpenShift 4 environment
#
#
function ct_os_set_ocp4() {
  if [ "${CVP:-0}" -eq "1" ]; then
    echo "Testing in CVP environment. No need to login to OpenShift cluster. This is already done by CVP pipeline."
    return
  fi
  local login
  OS_OC_CLIENT_VERSION=${OS_OC_CLIENT_VERSION:-4}
  ct_os_set_path_oc_4 "${OS_OC_CLIENT_VERSION}"

  login=$(cat "$KUBEPASSWORD")
  oc login -u kubeadmin -p "$login"
  oc version
  if ! oc version | grep -q "Client Version: ${OS_OC_CLIENT_VERSION}." ; then
    echo "ERROR: something went wrong, oc located at ${oc_path}, but oc of version ${OS_OC_CLIENT_VERSION} not found in PATH ($PATH)" >&1
    return 1
  else
    echo "PATH set correctly, binary oc found in version ${OS_OC_CLIENT_VERSION}: $(command -v oc)"
  fi
  # Switch to default project as soon as we are logged to cluster
  oc project default
  echo "Login to OpenShift ${OS_OC_CLIENT_VERSION} is DONE"
  # let openshift cluster to sync to avoid some race condition errors
  sleep 3
}

function ct_os_tag_image_for_cvp() {
  if [ "${CVP:-0}" -eq "0" ]; then
    echo "The function is valid only for CVP pipeline."
    return
  fi
  local tag_image_name="$1"
  local tag=""
  if [ "${OS}" == "rhel8" ]; then
    tag="-el8"
  elif [ "${OS}" == "rhel9" ]; then
    tag="-el9"
  else
    echo "Only RHEL images are supported."
    return
  fi
  oc tag "${tag_image_name}:${VERSION}" "${tag_image_name}:${VERSION}${tag}"
}

function ct_os_upload_image_external_registry() {
  local input_name="${1}" ; shift
  local image_name=${input_name##*/}
  local imagestream=${1:-$image_name:latest}
  local output_name

  ct_os_login_external_registry

  output_name="${INTERNAL_DOCKER_REGISTRY}/rhscl-ci-testing/$imagestream"

  docker images
  docker tag "${input_name}" "${output_name}"
  docker push "${output_name}"
}


function ct_os_import_image_ocp4() {
  local image_name="${1}"; shift
  local imagestream=${1:-$image_name:latest}

  echo "Uploading image ${image_name} as ${imagestream} into OpenShift internal registry."
  ct_os_upload_image "${image_name}" "${imagestream}"

}

# ct_os_check_login
# ---------------
# function checks if the login to openshift was successful
# if successful returns 0
# if not, write error message, sets test result to 1
# and exits with non-zero
# Uses: $TESTSUITE_RESULT - overall result of all tests
function ct_os_check_login() {
  oc status || {
    echo "-------------------------------------------"
    echo "It looks like oc is not properly logged in."
    # shellcheck disable=SC2034
    TESTSUITE_RESULT=1
    return 1
  }
}
