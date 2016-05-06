#!/bin/bash

set -e

# Runs the nodejs application server. If the container is run in development mode,
# hot deploy and debugging are enabled.
run_node() {
  if [ "$DEV_MODE" == true ]; then
    exec nodemon --debug="$DEBUG_PORT"
  else
    exec npm start -d
  fi
} 

# If the official dockerhub node image is used, skip the SCL setup below
# and just run the nodejs server
if [ -d "/usr/src/app" ]; then
  run_node
fi

# Allow users to inspect/debug the builder image itself, by using:
# $ docker run -i -t openshift/centos-nodejs-builder --debug
#
[ "$1" == "--debug" ] && exec /bin/bash

run_node
