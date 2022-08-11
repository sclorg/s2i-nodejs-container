NodeJS 16 minimal container image
=========================

This container image includes Node.JS 16 on top of a minimal base image for your Node.JS 16 applications. This image is designed to be used
with the full-sized s2i-enabled Node.JS 16 image to build the application. The image can be used as a standalone s2i-enabled image as well,
but compared to the full-sized Node.JS 16 image it will be missing many build-time dependencies.
Users can choose between RHEL, CentOS and Fedora based images.
The RHEL images are available in the [Red Hat Container Catalog](https://access.redhat.com/containers/),
the CentOS images are available on [Quay.io](https://quay.io/organization/centos7),
and the Fedora images are available in [Quay.io](https://quay.io/organization/fedora).
The resulting image can be run using [podman](https://github.com/containers/libpod).

Note: while the examples in this README are calling `podman`, you can replace any such calls by `docker` with the same arguments

Description
-----------

Node.js 16 available as a minimal container is a base platform for
running various Node.js 16 applications and frameworks.
Node.js is a platform built on Chrome's JavaScript runtime for easily building
fast, scalable network applications. Node.js uses an event-driven, non-blocking I/O model
that makes it lightweight and efficient, perfect for data-intensive real-time applications
that run across distributed devices.

Usage in OpenShift
------------------
In this example, we will assume that you are using the `ubi8/nodejs-16` image, available via `nodejs:16-ubi8` imagestream tag in Openshift
to build the application, as well as the `ubi8/nodejs-16-minimal` image, available via `nodejs:16-ubi8-minimal` image stream
for running the resulting application.

With these two images we can create a [chained build](https://docs.openshift.com/container-platform/4.7/cicd/builds/advanced-build-operations.html#builds-chaining-builds_advanced-build-operations) in Openshift using two BuildConfigs:

The first BuildConfig defines and builds the builder image, using the source-to-image strategy, and pushes the result into
the `nodejs-builder-image` imagestream.

```
apiVersion: build.openshift.io/v1
kind: BuildConfig
metadata:
  name: nodejs-builder-image
spec:
  output:
    to:
      kind: ImageStreamTag
      name: nodejs-builder-image:latest
  source:
    git:
      uri: https://github.com/sclorg/nodejs-ex.git
  strategy:
    sourceStrategy:
      from:
        kind: ImageStreamTag
        name: nodejs:16-ubi8
        namespace: openshift
```

The second BuildConfig takes the resulting image from the `nodejs-builder-image` imagestream, copies the application source (including build artifacts)
from the image and creates a new runtime image on top of the nodejs minimal image, with the application copied in and prepared to run.
The resulting runtime image is then pushed into the `nodejs-runtime-image` imagestream.

```
apiVersion: build.openshift.io/v1
kind: BuildConfig
metadata:
  name: nodejs-runtime-image
spec:
  output:
    to:
      kind: ImageStreamTag
      name: nodejs-runtime-image:latest
  source:
    dockerfile: |-
      FROM nodejs:16-ubi8-minimal
      COPY src $HOME
      CMD /usr/libexec/s2i/run
    images:
    - from:
        kind: ImageStreamTag
        name: nodejs-builder-image:latest
      paths:
      - sourcePath: /opt/app-root/src
        destinationDir: "."
  strategy:
    dockerStrategy:
      from:
        kind: ImageStreamTag
        name: nodejs:16-ubi8-minimal
  triggers:
  - imageChange: {}
    type: ImageChange
```

Source-to-Image framework and scripts
-------------------------------------
This image supports the [Source-to-Image](https://docs.openshift.com/container-platform/3.11/creating_images/s2i.html)
(S2I) strategy in OpenShift. The Source-to-Image is an OpenShift framework
which makes it easy to write images that take application source code as
an input, use a builder image like this Node.js container image, and produce
a new image that runs the assembled application as an output.

To support the Source-to-Image framework, only the `run` script is included in this image.

* The `/usr/libexec/s2i/run` script is set as the default command in the resulting container image (the new image with the application artifacts). It runs `npm run` for production, or `nodemon` if `DEV_MODE` is set to `true` (see the **Environment variables** section below).

Building an application using a Dockerfile
------------------------------------------
Compared to the Source-to-Image strategy, using a Dockerfile is a more
flexible way to build a Node.js container image with an application.
Use a Dockerfile when Source-to-Image is not sufficiently flexible for you or
when you build the image outside of the OpenShift environment.

To use the Node.js image in a Dockerfile, follow these steps:

#### 1. Pull the base builder and minimal runtime images

```
podman pull ubi8/nodejs-16
podman pull ubi8/nodejs-16-minimal
```

The UBI images `ubi8/nodejs-16` and `ubi8/nodejs-16-minimal` that are used in this example are both usable and freely redistributable under the terms of the UBI End User License Agreement (EULA). See more about UBI at [UBI FAQ](https://developers.redhat.com/articles/ubi-faq).

#### 2. Pull an application code

An example application available at https://github.com/sclorg/nodejs-ex.git is used here. Feel free to clone the repository for further experiments.

```
git clone https://github.com/sclorg/nodejs-ex.git app-src
```

#### 3. Prepare an application inside a container

This step usually consists of at least these parts:

* putting the application source into the container
* installing the dependencies
* setting the default command in the resulting image

For all these three parts, users can either setup all manually and use commands `nodejs` and `npm` explicitly in the Dockerfile ([3.1.](#31-to-use-your-own-setup-create-a-dockerfile-with-this-content)), or users can use the Source-to-Image scripts inside the image ([3.2.](#32-to-use-the-source-to-image-scripts-and-build-an-image-using-a-dockerfile-create-a-dockerfile-with-this-content); see more about these scripts in the section "Source-to-Image framework and scripts" above), that already know how to set-up and run some common Node.js applications.

##### 3.1. To use your own setup, create a Dockerfile with this content:
```
# First stage builds the application
FROM ubi8/nodejs-16 as builder

# Add application sources
ADD app-src $HOME

# Install the dependencies
RUN npm install

# Second stage copies the application to the minimal image
FROM ubi8/nodejs-16-minimal

# Copy the application source and build artifacts from the builder image to this one
COPY --from=builder $HOME $HOME

# Run script uses standard ways to run the application
CMD npm run -d start
```

##### 3.2. To use the Source-to-Image scripts and build an image using a Dockerfile, create a Dockerfile with this content:
```
# First stage builds the application
FROM ubi8/nodejs-16 as builder

# Add application sources to a directory that the assemble script expects them
# and set permissions so that the container runs without root access
USER 0
ADD app-src /tmp/src
RUN chown -R 1001:0 /tmp/src
USER 1001

# Install the dependencies
RUN /usr/libexec/s2i/assemble

# Second stage copies the application to the minimal image
FROM ubi8/nodejs-16-minimal

# Copy the application source and build artifacts from the builder image to this one
COPY --from=builder $HOME $HOME

# Set the default command for the resulting image
CMD /usr/libexec/s2i/run
```

#### 4. Build a new image from a Dockerfile prepared in the previous step

```
podman build -t node-app .
```

#### 5. Run the resulting image with the final application

```
podman run -d node-app
```

Environment variables for Source-to-Image
---------------------

Application developers can use the following environment variables to configure the runtime behavior of this image in OpenShift:

#### Used in the minimal image

**`NODE_ENV`**  
       NodeJS runtime mode (default: "production")

**`DEV_MODE`**  
       When set to "true", `nodemon` will be used to automatically reload the server while you work (default: "false"). Setting `DEV_MODE` to "true" will change the `NODE_ENV` default to "development" (if not explicitly set).

**`NPM_RUN`**  
       Select an alternate / custom runtime mode, defined in your `package.json` file's [`scripts`](https://docs.npmjs.com/misc/scripts) section (default: npm run "start"). These user-defined run-scripts are unavailable while `DEV_MODE` is in use.

#### Additional variables used in the full-sized image

**`HTTP_PROXY`**  
       Use an npm proxy during assembly

**`HTTPS_PROXY`**  
       Use an npm proxy during assembly

**`NPM_MIRROR`**  
       Use a custom NPM registry mirror to download packages during the build process

One way to define a set of environment variables is to include them as key value pairs in your repo's `.s2i/environment` file.

Example: DATABASE_USER=sampleUser

#### NOTE: Define your own "`DEV_MODE`":

The following `package.json` example includes a `scripts.dev` entry.  You can define your own custom [`NPM_RUN`](https://docs.npmjs.com/cli/run-script) scripts in your application's `package.json` file.

#### Note: Setting logging output verbosity
To alter the level of logs output during an `npm install` the npm_config_loglevel environment variable can be set. See [npm-config](https://docs.npmjs.com/misc/config).

Development Mode
----------------
This image supports development mode. This mode can be switched on and off with the environment variable `DEV_MODE`. `DEV_MODE` can either be set to `true` or `false`.
Development mode supports two features:
* Hot Deploy
* Debugging

The debug port can be specified with the environment variable `DEBUG_PORT`. `DEBUG_PORT` is only valid if `DEV_MODE=true`.

A simple example command for running the container in development mode is:
```
podman run --env DEV_MODE=true my-image-id
```

To run the container in development mode with a debug port of 5454, run:
```
$ podman run --env DEV_MODE=true DEBUG_PORT=5454 my-image-id
```

To run the container in production mode, run:
```
$ podman run --env DEV_MODE=false my-image-id
```

By default, `DEV_MODE` is set to `false`, and `DEBUG_PORT` is set to `5858`, however the `DEBUG_PORT` is only relevant if `DEV_MODE=true`.

Hot deploy
----------

As part of development mode, this image supports hot deploy. If development mode is enabled, any souce code that is changed in the running container will be immediately reflected in the running nodejs application.

### Using Podman's exec

To change your source code in a running container, use Podman's [exec](https://github.com/containers/libpod) command:
```
$ podman exec -it <CONTAINER_ID> /bin/bash
```

After you [Podman exec](https://github.com/containers/libpod) into the running container, your current directory is set to `/opt/app-root/src`, where the source code for your application is located.

### Using OpenShift's rsync

If you have deployed the container to OpenShift, you can use [oc rsync](https://docs.openshift.org/latest/dev_guide/copy_files_to_container.html) to copy local files to a remote container running in an OpenShift pod.

#### Warning:

The default behaviour of the s2i-nodejs container image is to run the Node.js application using the command `npm start`. This runs the _start_ script in the _package.json_ file. In developer mode, the application is run using the command `nodemon`. The default behaviour of nodemon is to look for the _main_ attribute in the _package.json_ file, and execute that script. If the _main_ attribute doesn't appear in the _package.json_ file, it executes the _start_ script. So, in order to achieve some sort of uniform functionality between production and development modes, the user should remove the _main_ attribute.

Below is an example _package.json_ file with the _main_ attribute and _start_ script marked appropriately:

```json
{
    "name": "node-echo",
    "version": "0.0.1",
    "description": "node-echo",
    "main": "example.js", <--- main attribute
    "dependencies": {
    },
    "devDependencies": {
        "nodemon": "*"
    },
    "engine": {
        "node": "*",
        "npm": "*"
    },
    "scripts": {
        "dev": "nodemon --ignore node_modules/ server.js",
        "start": "node server.js" <-- start script
    },
    "keywords": [
        "Echo"
    ],
    "license": "",
}
```

#### Note:
`oc rsync` is only available in versions 3.1+ of OpenShift.


See also
--------
Dockerfile and other sources are available on https://github.com/sclorg/s2i-nodejs-container.
In that repository you also can find another versions of Node.js environment Dockerfiles.
Dockerfile for CentOS is called `Dockerfile`, Dockerfile for RHEL7 is called `Dockerfile.rhel7`,
for RHEL8 it's `Dockerfile.rhel8` and the Fedora Dockerfile is called Dockerfile.fedora.
