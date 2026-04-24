FROM {{ spec.s2i_base }}{% if not ":" in spec.s2i_base and spec.prod != "c8s" %}:latest{% endif %}

# This image provides a Node.JS environment you can use to run your Node.JS
# applications.

EXPOSE 8080

# Add $HOME/node_modules/.bin to the $PATH, allowing user to make npm scripts
# available on the CLI without using npm's --global installation mode
# This image will be initialized with "npm run $NPM_RUN"
# See https://docs.npmjs.com/misc/scripts, and your repo's package.json
# file for possible values of NPM_RUN
# Description
# Environment:
# * $NPM_RUN - Select an alternate / custom runtime mode, defined in your package.json files' scripts section (default: npm run "start").
# Expose ports:
# * 8080 - Unprivileged port used by nodejs application

ENV NODEJS_VERSION={{ spec.version }} \
    NPM_RUN=start \
    NAME=nodejs \
    NPM_CONFIG_PREFIX=$HOME/.npm-global \
    PATH=$HOME/node_modules/.bin/:$HOME/.npm-global/bin/:$PATH{% if spec.prod != "fedora" %} \
    CNB_STACK_ID=com.redhat.stacks.{{ spec.prod }}-nodejs-{{ spec.version }} \
    CNB_USER_ID=1001 \
    CNB_GROUP_ID=0
{% endif %}

ENV SUMMARY="Platform for building and running Node.js $NODEJS_VERSION applications" \
    DESCRIPTION="Node.js $NODEJS_VERSION available as container is a base platform for \
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
      io.openshift.tags="builder,$NAME,$NAME$NODEJS_VERSION" \
      io.openshift.s2i.scripts-url="image:///usr/libexec/s2i" \
      io.s2i.scripts-url="image:///usr/libexec/s2i"{% if spec.prod != "fedora" %} \
      io.buildpacks.stack.id="com.redhat.stacks.{{ spec.prod }}-nodejs-{{ spec.version }}"{% endif %} \
      com.redhat.dev-mode="DEV_MODE:false" \
      com.redhat.deployments-dir="${APP_ROOT}/src" \
      com.redhat.dev-mode.port="DEBUG_PORT:5858"{% if spec.prod != "fedora" %} \
      com.redhat.component="{{ spec.redhat_component }}" \{% endif %}
      name="{{ spec.img_name }}" \
      version="{% if spec.prod != "fedora" %}1{% else %}$NODEJS_VERSION{% endif %}"{% if spec.prod != "fedora" %} \
      com.redhat.license_terms="https://www.redhat.com/en/about/red-hat-end-user-license-agreements#UBI"{% endif %} \
      maintainer="SoftwareCollections.org <sclorg@redhat.com>" \
      help="For more information visit https://github.com/sclorg/s2i-nodejs-container" \
      usage="{% if spec.prod != "fedora" %}s2i build <SOURCE-REPOSITORY> {{ spec.img_name }}:latest <APP-NAME>{% else %}oc new-app $FGC/$NAME~<SOURCE-REPOSITORY>{% endif %}"

{% if spec.environment_setup %}
RUN {{ spec.environment_setup }}{% endif %}
    MODULE_DEPS="make gcc gcc-c++ libatomic_ops git openssl-devel" && \
    INSTALL_PKGS="$MODULE_DEPS {{ spec.pkgs }}" && \
{% if spec.prod == "fedora" %}    yum install -y --setopt=tsflags=nodocs $INSTALL_PKGS && \
    rpm -V $INSTALL_PKGS && \
    ln -s /usr/bin/node-$NODEJS_VERSION /usr/bin/node && \
    ln -s /usr/bin/npm-$NODEJS_VERSION /usr/bin/npm && \
    ln -s /usr/bin/npx-$NODEJS_VERSION /usr/bin/npx && \
    ln -s /usr/lib/node_modules_18/nodemon /usr/lib/node_modules_$NODEJS_VERSION/nodemon && \
    node -v | grep -qe "^v$NODEJS_VERSION\." && echo "Found VERSION $NODEJS_VERSION" && \{% else %}    ln -s /usr/lib/node_modules/nodemon/bin/nodemon.js /usr/bin/nodemon && \
    ln -s /usr/libexec/platform-python /usr/bin/python3 && \
    yum install -y --setopt=tsflags=nodocs $INSTALL_PKGS && \
    rpm -V $INSTALL_PKGS && \
    node -v | grep -qe "^v$NODEJS_VERSION\." && echo "Found VERSION $NODEJS_VERSION" && \{% endif %}
    yum -y clean all --enablerepo='*'{% if config.post_install %}

RUN {{ spec.post_install }}{% endif %}

# Copy the S2I scripts from the specific language image to $STI_SCRIPTS_PATH
COPY ./s2i/bin/ $STI_SCRIPTS_PATH
RUN chmod +x $STI_SCRIPTS_PATH/init-wrapper

# Copy extra files to the image.
COPY ./root/ /

# Drop the root user and make the content of /opt/app-root owned by user 1001
RUN chown -R 1001:0 ${APP_ROOT} && chmod -R ug+rwx ${APP_ROOT} && \
    rpm-file-permissions

USER 1001

# Set the default CMD to print the usage of the language image
CMD $STI_SCRIPTS_PATH/usage