FROM openshift/base-centos7

# This image provides a Node.JS environment you can use to run your Node.JS
# applications.

MAINTAINER Jakub Hadvig <jhadvig@redhat.com>

EXPOSE 8080

ENV NODEJS_VERSION 0.10
LABEL k8s.io/description="Platform for building and running Node.js 0.10 applications" \
      k8s.io/display-name="Node.js 0.10" \
      openshift.io/expose-services="8080:http" \
      openshift.io/tags="builder,nodejs,nodejs010"

# Copy the STI scripts from the specific language image to /usr/local/sti
COPY ./.sti/bin/ /usr/local/sti

# Each language image can have 'contrib' a directory with extra files needed to
# run and build the applications.
COPY ./contrib/ /opt/openshift

RUN yum install -y \
    https://www.softwarecollections.org/en/scls/rhscl/v8314/epel-7-x86_64/download/rhscl-v8314-epel-7-x86_64.noarch.rpm \
    https://www.softwarecollections.org/en/scls/rhscl/nodejs010/epel-7-x86_64/download/rhscl-nodejs010-epel-7-x86_64.noarch.rpm && \
    yum install -y --setopt=tsflags=nodocs nodejs010 && \
    yum clean all -y && \
    chown -R default:default /opt/openshift

USER 1001

# Set the default CMD to print the usage of the language image
CMD ["usage"]
