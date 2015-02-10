#!/bin/bash -e
# $1 - Specifies distribution - RHEL7/CentOS7
# $2 - Specifies NodeJS version - 0.10

# Array of all versions of NodeJS
declare -a VERSIONS=(0.10)

OS=$1
VERSION=$2

if [ -z ${VERSION} ]; then
  # Build all versions
  dirs=${VERSIONS}
else
  # Build only specified version on NodeJS
  dirs=${VERSION}
fi

for dir in ${dirs}; do
  IMAGE_NAME=nodejs-${dir}-${OS}
  echo "---> Building ${IMAGE_NAME}"

  pushd ${dir} > /dev/null

  if [ "$OS" == "rhel7" ]; then
    mv Dockerfile Dockerfile.centos7
    mv Dockerfile.rhel7 Dockerfile
    docker build -t ${IMAGE_NAME} .
    mv Dockerfile Dockerfile.rhel7
    mv Dockerfile.centos7 Dockerfile
  else
    docker build -t ${IMAGE_NAME} .
  fi

  popd > /dev/null
done
