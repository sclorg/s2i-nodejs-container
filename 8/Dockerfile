FROM centos/s2i-base-centos7

# This image provides a Node.JS environment you can use to run your Node.JS
# applications.

# Add $HOME/node_modules/.bin to the $PATH, allowing user to make npm scripts
# available on the CLI without using npm's --global installation mode
# This image will be initialized with "npm run $NPM_RUN"
# See https://docs.npmjs.com/misc/scripts, and your repo's package.json
# file for possible values of NPM_RUN
# Description
# Environment:
# * $HOME_APP_ROOT - Root directory of application
# * $NPM_RUN - Select an alternate / custom runtime mode, defined in your package.json files' scripts section (default: npm run "start").
# Expose ports:
# * 8080 - Unprivileged port used by nodejs application
# Additional packages
# * findutils are needed to help fix permissions

ENV NODEJS_VERSION=8 \
    NPM_RUN=start \
    HOME_APP_ROOT=/opt/app_root \
    NPM_CONFIG_PREFIX=$HOME/.npm-global \
    PATH=$HOME/node_modules/.bin/:$HOME/.npm-global/bin/:$PATH

ENV SUMMARY="Platform for building and running Node.js $NODEJS_VERSION applications" \
    DESCRIPTION="Node.js $NODEJS_VERSION available as docker container is a base platform for \
building and running various Node.js $NODEJS_VERSION applications and frameworks. \
Node.js is a platform built on Chrome's JavaScript runtime for easily building \
fast, scalable network applications. Node.js uses an event-driven, non-blocking I/O model \
that makes it lightweight and efficient, perfect for data-intensive real-time applications \
that run across distributed devices."

LABEL summary="$SUMMARY" \
      description="$DESCRIPTION" \
      io.k8s.description="$DESCRIPTION" \
      io.k8s.display-name="Node.js $NODEJS_VERSION" \
      io.openshift.expose-services="8080:http" \
      io.openshift.tags="builder,nodejs,nodejs$NODEJS_VERSION" \
      io.openshift.s2i.scripts-url="image:///usr/libexec/s2i" \
      io.s2i.scripts-url="image:///usr/libexec/s2i" \
      com.redhat.dev-mode="DEV_MODE:false" \
      com.redhat.deployments-dir="/opt/app-root/src" \
      com.redhat.dev-mode.port="DEBUG_PORT:5858"\
      com.redhat.component="rh-nodejs8-docker" \
      name="centos/nodejs-8-centos7" \
      version="1" \
      maintainer="SoftwareCollections.org <sclorg@redhat.com>" \
      help="For more information visit https://github.com/sclorg/s2i-nodejs-container" \
      usage="s2i build <SOURCE-REPOSITORY> nodejs:8 <APP-NAME>

EXPOSE 8080

RUN yum install -y centos-release-scl-rh && \
    yum remove -y rh-nodejs6\* && \
    yum-config-manager --enable centos-sclo-rh-testing && \
    INSTALL_PKGS="rh-nodejs8 rh-nodejs8-npm rh-nodejs8-nodejs-nodemon nss_wrapper" && \
    ln -s /usr/lib/node_modules/nodemon/bin/nodemon.js /usr/bin/nodemon && \
    yum install -y --setopt=tsflags=nodocs $INSTALL_PKGS && \
    rpm -V $INSTALL_PKGS && \
    yum clean all -y

# Copy the S2I scripts from the specific language image to $STI_SCRIPTS_PATH
COPY ./s2i/bin/ $STI_SCRIPTS_PATH

# Copy extra files to the image. Including help file.
COPY ./root/ /

# Drop the root user and make the content of /opt/app-root owned by user 1001
RUN chown -R 1001:0 /opt/app-root && chmod -R ug+rwx /opt/app-root && \
    rpm-file-permissions

USER 1001

# Set the default CMD to print the usage of the language image
CMD $STI_SCRIPTS_PATH/usage
