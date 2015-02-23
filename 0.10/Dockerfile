FROM openshift/base-centos7

# Image metadata
ENV NODEJS_VERSION        = "0.10" \
    IMAGE_DESCRIPTION     = "Node.js 0.10" \
    IMAGE_TAGS            = "node,nodejs,nodejs010" \
    IMAGE_EXPOSE_SERVICES = "3000:http"

RUN yum install -y \
    https://www.softwarecollections.org/en/scls/rhscl/v8314/epel-7-x86_64/download/rhscl-v8314-epel-7-x86_64.noarch.rpm \
    https://www.softwarecollections.org/en/scls/rhscl/nodejs010/epel-7-x86_64/download/rhscl-nodejs010-epel-7-x86_64.noarch.rpm && \
    yum install -y --setopt=tsflags=nodocs nodejs010 && \
    yum clean all -y

USER default

# Copy the nodejs scripts and build tools into /opt/openshift directory
# TODO: There is a bug in Docker < 1.5 that disallows to use './..' as dest
#       directory.
COPY ./nodejs/ /opt/openshift/

EXPOSE 3000
