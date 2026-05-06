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
    CNB_STACK_ID=com.redhat.stacks.{{ spec.org }}-nodejs-{{ spec.version }} \
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
      io.openshift.tags="builder,$NAME,${NAME}${NODEJS_VERSION}" \
      io.openshift.s2i.scripts-url="image:///usr/libexec/s2i" \
      io.s2i.scripts-url="image:///usr/libexec/s2i"{% if spec.prod != "fedora" %} \
      io.buildpacks.stack.id="com.redhat.stacks.{{ spec.org }}-nodejs-{{ spec.version }}"{% endif %} \
      com.redhat.dev-mode="DEV_MODE:false" \
      com.redhat.deployments-dir="${APP_ROOT}/src" \
      com.redhat.dev-mode.port="DEBUG_PORT:5858"{% if spec.prod != "fedora" %} \
      com.redhat.component="{{ spec.redhat_component }}" \
{% endif %}      name="{{ spec.img_name }}" \
{% if spec.prod == "fedora" %}      version="$NODEJS_VERSION" \
{% elif spec.prod != "rhel10" %}      version="1" \
{% endif %}{% if spec.prod != "fedora" %}
      com.redhat.license_terms="https://www.redhat.com/en/about/red-hat-end-user-license-agreements#UBI"{% endif %} \
      maintainer="SoftwareCollections.org <sclorg@redhat.com>" \
      help="For more information visit https://github.com/sclorg/s2i-nodejs-container" \
      usage="{% if spec.prod != "fedora" %}s2i build <SOURCE-REPOSITORY> {% if spec.prod in ["c8s", "c9s", "c10s"] %}quay.io/{% endif %}{{ spec.img_name }}{% if spec.prod != "rhel10" %}:latest{% endif %} <APP-NAME>{% else %}oc new-app $FGC/$NAME~<SOURCE-REPOSITORY>{% endif %}"

{% if spec.prod in ["c9s", "rhel10", "c10s"] %}
# Package libatomic_ops was removed
{% endif %}{% if spec.prod in ["rhel10", "c10s"] and spec.version == "22" %}
RUN INSTALL_PKGS="make gcc gcc-c++ git openssl-devel nodejs nodejs-nodemon nodejs-npm nss_wrapper-libs which" && \
    dnf install -y --setopt=tsflags=nodocs $INSTALL_PKGS && \
    rpm -V $INSTALL_PKGS && \
    rm /usr/bin/node && ln -s /usr/bin/node-$NODEJS_VERSION /usr/bin/node && \
    rm /usr/bin/npm && ln -s /usr/bin/npm-$NODEJS_VERSION /usr/bin/npm && \
    rm /usr/bin/npx && ln -s /usr/bin/npx-$NODEJS_VERSION /usr/bin/npx && \
    node -v | grep -qe "^v$NODEJS_VERSION\." && echo "Found VERSION $NODEJS_VERSION" && \
    dnf -y clean all --enablerepo='*'
{% elif spec.prod in ["rhel10", "c10s"] and spec.version == "24" %}
RUN INSTALL_PKGS="make gcc gcc-c++ git openssl-devel nodejs$NODEJS_VERSION nodejs-nodemon nodejs$NODEJS_VERSION-npm nss_wrapper-libs which" && \
    dnf install -y --setopt=tsflags=nodocs $INSTALL_PKGS && \
    rpm -V $INSTALL_PKGS && \
    ln -s /usr/bin/node-$NODEJS_VERSION /usr/bin/node && \
    ln -s /usr/bin/npm-$NODEJS_VERSION /usr/bin/npm && \
    ln -s /usr/bin/npx-$NODEJS_VERSION /usr/bin/npx && \
    node -v | grep -qe "^v$NODEJS_VERSION\." && echo "Found VERSION $NODEJS_VERSION" && \
    dnf -y clean all --enablerepo='*'
{% elif spec.environment_setup %}
{% if spec.prod == "rhel8" and spec.version == "20" -%}
RUN yum -y module enable nodejs:$NODEJS_VERSION && \
    MODULE_DEPS="make gcc gcc-c++ libatomic_ops git openssl-devel" && \
    INSTALL_PKGS="$MODULE_DEPS {{ spec.pkgs }}" && \
    ln -s /usr/lib/node_modules/nodemon/bin/nodemon.js /usr/bin/nodemon && \
    ln -s /usr/libexec/platform-python /usr/bin/python3 && \
    yum install -y --setopt=tsflags=nodocs $INSTALL_PKGS && \
    rpm -V $INSTALL_PKGS && \
    node -v | grep -qe "^v$NODEJS_VERSION\." && echo "Found VERSION $NODEJS_VERSION" && \
    yum -y clean all --enablerepo='*'
{% elif spec.prod == "c8s" and spec.version == "20" -%}
RUN yum -y module enable nodejs:$NODEJS_VERSION && \
    MODULE_DEPS="make gcc gcc-c++ libatomic_ops git openssl-devel" && \
    INSTALL_PKGS="$MODULE_DEPS {{ spec.pkgs }}" && \
    ln -s /usr/lib/node_modules/nodemon/bin/nodemon.js /usr/bin/nodemon && \
    ln -s /usr/libexec/platform-python /usr/bin/python3 && \
    yum install -y --setopt=tsflags=nodocs $INSTALL_PKGS && \
    rpm -V $INSTALL_PKGS && \
    node -v | grep -qe "^v$NODEJS_VERSION\." && echo "Found VERSION $NODEJS_VERSION" && \
    yum -y clean all --enablerepo='*'
{% elif spec.prod == "c9s" and spec.version == "20" -%}
RUN yum -y module enable nodejs:$NODEJS_VERSION && \
    MODULE_DEPS="make gcc gcc-c++ git openssl-devel" && \
    INSTALL_PKGS="$MODULE_DEPS {{ spec.pkgs }}" && \
    ln -s /usr/lib/node_modules/nodemon/bin/nodemon.js /usr/bin/nodemon && \
    yum install -y --setopt=tsflags=nodocs $INSTALL_PKGS && \
    rpm -V $INSTALL_PKGS && \
    node -v | grep -qe "^v$NODEJS_VERSION\." && echo "Found VERSION $NODEJS_VERSION" && \
    yum -y clean all --enablerepo='*'
{% elif spec.prod == "rhel9" and spec.version == "20" -%}
RUN yum -y module enable nodejs:$NODEJS_VERSION && \
    MODULE_DEPS="make gcc gcc-c++ git openssl-devel" && \
    INSTALL_PKGS="$MODULE_DEPS {{ spec.pkgs }}" && \
    ln -s /usr/lib/node_modules/nodemon/bin/nodemon.js /usr/bin/nodemon && \
    yum install -y --setopt=tsflags=nodocs $INSTALL_PKGS && \
    rpm -V $INSTALL_PKGS && \
    node -v | grep -qe "^v$NODEJS_VERSION\." && echo "Found VERSION $NODEJS_VERSION" && \
    yum -y clean all --enablerepo='*'
{% elif spec.prod == "rhel8" and spec.version != "20" -%}
RUN {{ spec.environment_setup }}
    MODULE_DEPS="make gcc-toolset-13-gcc gcc-toolset-13-gcc-c++ gcc-toolset-13-runtime \
        libatomic_ops git openssl-devel python3.12" && \
    INSTALL_PKGS="$MODULE_DEPS {{ spec.pkgs }}" && \
    ln -s /usr/lib/node_modules/nodemon/bin/nodemon.js /usr/bin/nodemon && \
    dnf install -y --setopt=tsflags=nodocs $INSTALL_PKGS && \
    rpm -V $INSTALL_PKGS && \
    node -v | grep -qe "^v$NODEJS_VERSION\." && echo "Found VERSION $NODEJS_VERSION" && \
    dnf -y clean all --enablerepo='*'
{% elif spec.prod == "c8s" -%}
RUN {{ spec.environment_setup }}
    MODULE_DEPS="make gcc gcc-c++ libatomic_ops git openssl-devel" && \
    INSTALL_PKGS="$MODULE_DEPS {{ spec.pkgs }}" && \
    ln -s /usr/lib/node_modules/nodemon/bin/nodemon.js /usr/bin/nodemon && \
    ln -s /usr/libexec/platform-python /usr/bin/python3 && \
    yum install -y --setopt=tsflags=nodocs $INSTALL_PKGS && \
    rpm -V $INSTALL_PKGS && \
    node -v | grep -qe "^v$NODEJS_VERSION\." && echo "Found VERSION $NODEJS_VERSION" && \
    yum -y clean all --enablerepo='*'
{% else -%}
RUN {{ spec.environment_setup }}
    MODULE_DEPS="make gcc gcc-c++{% if spec.prod not in ["c9s", "rhel9"] %} libatomic_ops{% endif %} git openssl-devel" && \
    INSTALL_PKGS="$MODULE_DEPS {{ spec.pkgs }}" && \
    ln -s /usr/lib/node_modules/nodemon/bin/nodemon.js /usr/bin/nodemon && \
    dnf install -y --setopt=tsflags=nodocs $INSTALL_PKGS && \
    rpm -V $INSTALL_PKGS && \
    node -v | grep -qe "^v$NODEJS_VERSION\." && echo "Found VERSION $NODEJS_VERSION" && \
    dnf -y clean all --enablerepo='*'
{% endif -%}
{% else %}
RUN MODULE_DEPS="make {% if spec.prod == "rhel8" and spec.version != "20" %}gcc-toolset-13-gcc gcc-toolset-13-gcc-c++ gcc-toolset-13-runtime \
        libatomic_ops git openssl-devel python3.12{% else %}gcc gcc-c++{% if spec.prod not in ["c9s", "rhel9"] %} libatomic_ops{% endif %} git openssl-devel{% endif %}" && \
    INSTALL_PKGS="$MODULE_DEPS {{ spec.pkgs }}" && \
    ln -s /usr/lib/node_modules/nodemon/bin/nodemon.js /usr/bin/nodemon && \
{% if spec.prod in ["c8s"] or (spec.prod == "rhel8" and spec.version == "20") %}    ln -s /usr/libexec/platform-python /usr/bin/python3 && \
{% endif %}    {% if spec.prod == "c8s" or (spec.prod == "rhel8" and spec.version == "20") or (spec.prod == "c9s" and spec.version == "20") %}yum{% else %}dnf{% endif %} install -y --setopt=tsflags=nodocs $INSTALL_PKGS && \
    rpm -V $INSTALL_PKGS && \
    node -v | grep -qe "^v$NODEJS_VERSION\." && echo "Found VERSION $NODEJS_VERSION" && \
{% if spec.prod == "c8s" or (spec.prod == "rhel8" and spec.version == "20") or (spec.prod == "c9s" and spec.version == "20") %}    yum{% else %}    dnf{% endif %} -y clean all --enablerepo='*'
{% endif %}{% if config.post_install %}

RUN {{ spec.post_install }}{% endif %}

# Copy the S2I scripts from the specific language image to $STI_SCRIPTS_PATH
COPY ./s2i/bin/ $STI_SCRIPTS_PATH
RUN chmod +x {% if spec.version == "20" %}$STI_SCRIPTS_PATH/init-wrapper

{% else %}/usr/libexec/s2i/init-wrapper

{% endif %}# Copy extra files to the image.
COPY ./root/ /

# Drop the root user and make the content of /opt/app-root owned by user 1001
RUN chown -R 1001:0 ${APP_ROOT} && chmod -R ug+rwx ${APP_ROOT} && \
    rpm-file-permissions

USER 1001

{% if spec.prod == "rhel8" and spec.version != "20" %}
# Enable the SCL for all bash scripts.
ENV BASH_ENV=/opt/rh/gcc-toolset-13/enable \
    ENV=/opt/rh/gcc-toolset-13/enable \
    PROMPT_COMMAND=". /opt/rh/gcc-toolset-13/enable"

{% endif %}# Set the default CMD to print the usage of the language image
CMD $STI_SCRIPTS_PATH/usage
