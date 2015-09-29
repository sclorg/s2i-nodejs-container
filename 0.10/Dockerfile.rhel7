FROM openshift/base-rhel7

# This image provides a Node.JS environment you can use to run your Node.JS
# applications.

EXPOSE 8080

ENV NODEJS_VERSION 0.10

LABEL io.k8s.description="Platform for building and running Node.js 0.10 applications" \
      io.k8s.display-name="Node.js 0.10" \
      io.openshift.expose-services="8080:http" \
      io.openshift.tags="builder,nodejs,nodejs010"

# Labels consumed by Red Hat build service
LABEL BZComponent="nodejs010" \
      Name="openshift3/nodejs-010-rhel7" \
      Version="0.10" \
      Release="1" \
      Architecture="x86_64"

RUN yum-config-manager --enable rhel-server-rhscl-7-rpms && \
    yum-config-manager --enable rhel-7-server-optional-rpms && \
    yum install -y --setopt=tsflags=nodocs nodejs010 && \
    yum clean all -y

# Copy the S2I scripts from the specific language image to $STI_SCRIPTS_PATH
COPY ./s2i/bin/ $STI_SCRIPTS_PATH

# Each language image can have 'contrib' a directory with extra files needed to
# run and build the applications.
COPY ./contrib/ /opt/app-root

# Drop the root user and make the content of /opt/app-root owned by user 1001
RUN chown -R 1001:0 /opt/app-root
USER 1001

# Set the default CMD to print the usage of the language image
CMD $STI_SCRIPTS_PATH/usage
