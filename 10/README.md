NodeJS 10 container image
===================

This container image includes Node.JS 10 as a [S2I](https://github.com/openshift/source-to-image) base image for your Node.JS 10 applications.
Users can choose between RHEL, CentOS and Fedora based images.
The RHEL images are available in the [Red Hat Container Catalog](https://access.redhat.com/containers/),
the CentOS images are available on [Podman Hub](https://hub.docker.com/r/centos/),
and the Fedora images are available in [Fedora Registry](https://registry.fedoraproject.org/).
The resulting image can be run using [podman](https://github.com/containers/libpod).

Note: while the examples in this README are calling `podman`, you can replace any such calls by `docker` with the same arguments

Description
-----------

Node.js 10 available as container is a base platform for 
building and running various Node.js 10 applications and frameworks. 
Node.js is a platform built on Chrome's JavaScript runtime for easily building 
fast, scalable network applications. Node.js uses an event-driven, non-blocking I/O model 
that makes it lightweight and efficient, perfect for data-intensive real-time applications 
that run across distributed devices.

Usage
---------------------
For this, we will assume that you are using the `ubi8/nodejs-10 image`, available via `nodejs:10` imagestream tag in Openshift.
Building a simple [nodejs-sample-app](https://github.com/sclorg/s2i-nodejs-container/tree/master/10/test/test-app) application
in Openshift can be achieved with the following step:

    ```
    oc new-app nodejs:10~https://github.com/sclorg/s2i-nodejs-container.git --context-dir=10/test/test-app/
    ```

The same application can also be built using the standalone [S2I](https://github.com/openshift/source-to-image) application on systems that have it available:

    ```
    $ s2i build https://github.com/sclorg/s2i-nodejs-container.git --context-dir=10/test/test-app/ ubi8/nodejs-10 nodejs-sample-app
    ```

**Accessing the application:**
```
$ curl 127.0.0.1:8080
```

Environment variables
---------------------

Application developers can use the following environment variables to configure the runtime behavior of this image:

**`NODE_ENV`**  
       NodeJS runtime mode (default: "production")

**`DEV_MODE`**  
       When set to "true", `nodemon` will be used to automatically reload the server while you work (default: "false"). Setting `DEV_MODE` to "true" will change the `NODE_ENV` default to "development" (if not explicitly set).

**`NPM_RUN`**  
       Select an alternate / custom runtime mode, defined in your `package.json` file's [`scripts`](https://docs.npmjs.com/misc/scripts) section (default: npm run "start"). These user-defined run-scripts are unavailable while `DEV_MODE` is in use.

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
---------------------
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
--------------------

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
In that repository you also can find another versions of Python environment Dockerfiles.
Dockerfile for CentOS is called `Dockerfile`, Dockerfile for RHEL7 is called `Dockerfile.rhel7`,
for RHEL8 it's `Dockerfile.rhel8` and the Fedora Dockerfile is called Dockerfile.fedora.
