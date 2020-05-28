#!/bin/bash
#
# Functions for tests for the Node.js image in OpenShift.
#
# IMAGE_NAME specifies a name of the candidate image used for testing.
# The image has to be available before this script is executed.
#

THISDIR=$(dirname ${BASH_SOURCE[0]})

source "${THISDIR}/test-lib.sh"
source "${THISDIR}/test-lib-openshift.sh"

# Check the imagestream
function test_nodejs_imagestream() {
  case ${OS} in
    rhel7|centos7) ;;
    *) echo "Imagestream testing not supported for $OS environment." ; return 0 ;;
  esac

  ct_os_test_image_stream_quickstart "${THISDIR}/../imagestreams/nodejs-${OS}.json" \
                                     "https://raw.githubusercontent.com/sclorg/nodejs-ex/master/openshift/templates/nodejs.json" \
                                     "${IMAGE_NAME}" \
                                     'nodejs' \
                                     "Welcome to your Node.js application on OpenShift" \
                                     8080 http 200 "-p SOURCE_REPOSITORY_REF=master -p SOURCE_REPOSITORY_URL=https://github.com/sclorg/nodejs-ex.git -p NODEJS_VERSION=${VERSION} -p NAME=nodejs-testing"
}

# vim: set tabstop=2:shiftwidth=2:expandtab:

