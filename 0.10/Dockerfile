FROM openshift/base-centos7

# This image provides a Node.JS environment you can use to run your Node.JS
# applications.

MAINTAINER Jakub Hadvig <jhadvig@redhat.com>

# Image metadata
ENV NODEJS_VERSION        0.10
ENV IMAGE_DESCRIPTION     Node.js 0.10
ENV IMAGE_TAGS            node,nodejs,nodejs010
ENV IMAGE_EXPOSE_SERVICES 8080:http

RUN yum install -y \
    https://www.softwarecollections.org/en/scls/rhscl/v8314/epel-7-x86_64/download/rhscl-v8314-epel-7-x86_64.noarch.rpm \
    https://www.softwarecollections.org/en/scls/rhscl/nodejs010/epel-7-x86_64/download/rhscl-nodejs010-epel-7-x86_64.noarch.rpm && \
    yum install -y --setopt=tsflags=nodocs nodejs010 && \
    yum clean all -y

EXPOSE 8080

# Copy the STI scripts from the specific language image to /usr/local/sti
COPY ./.sti/bin/ /usr/local/sti

# Each language image can have 'contrib' a directory with extra files needed to
# run and build the applications.
COPY ./contrib/ /opt/openshift

RUN chown -R default:default /opt/openshift

USER default

# Set the default CMD to print the usage of the language image
CMD ["usage"]
