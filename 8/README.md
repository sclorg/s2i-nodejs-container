NodeJS 8 Docker image
===================

This container image includes Node.JS 8 as a [S2I](https://github.com/openshift/source-to-image) base image for your Node.JS 8 applications.
Users can choose between RHEL and CentOS based builder images.
The RHEL image is available in the [Red Hat Container Catalog](https://access.redhat.com/containers/#/registry.access.redhat.com/rhscl/nodejs-8-rhel7)
as registry.access.redhat.com/rhscl/nodejs-8-rhel7.
The CentOS image is then available on [Docker Hub](https://hub.docker.com/r/centos/nodejs-8-centos7/)
as centos/nodejs-8-centos7. 
The resulting image can be run using [Docker](http://docker.io).

Description
-----------

Node.js 8 available as docker container is a base platform for 
building and running various Node.js 8 applications and frameworks. 
Node.js is a platform built on Chrome's JavaScript runtime for easily building 
fast, scalable network applications. Node.js uses an event-driven, non-blocking I/O model 
that makes it lightweight and efficient, perfect for data-intensive real-time applications 
that run across distributed devices.

Usage
---------------------
To build a simple [nodejs-sample-app](https://github.com/sclorg/s2i-nodejs-container/tree/master/8/test/test-app) application
using standalone [S2I](https://github.com/openshift/source-to-image) and then run the
resulting image with [Docker](http://docker.io) execute:

*  **For RHEL based image**
    ```
    $ s2i build https://github.com/sclorg/s2i-nodejs-container.git --context-dir=8/test/test-app/ rhscl/nodejs-8-rhel7 nodejs-sample-app
    $ docker run -p 8080:8080 nodejs-sample-app
    ```

*  **For CentOS based image**
    ```
    $ s2i build https://github.com/sclorg/s2i-nodejs-container.git --context-dir=8/test/test-app/ centos/nodejs-8-centos7 nodejs-sample-app
    $ docker run -p 8080:8080 nodejs-sample-app
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

A simple example command for running the docker container in development mode is:
```
docker run --env DEV_MODE=true my-image-id
```

To run the container in development mode with a debug port of 5454, run:
```
$ docker run --env DEV_MODE=true DEBUG_PORT=5454 my-image-id
```

To run the container in production mode, run:
```
$ docker run --env DEV_MODE=false my-image-id
```

By default, `DEV_MODE` is set to `false`, and `DEBUG_PORT` is set to `5858`, however the `DEBUG_PORT` is only relevant if `DEV_MODE=true`.

Hot deploy
--------------------

As part of development mode, this image supports hot deploy. If development mode is enabled, any souce code that is changed in the running container will be immediately reflected in the running nodejs application.

### Using Docker's exec

To change your source code in a running container, use Docker's [exec](http://docker.io) command:
```
$ docker exec -it <CONTAINER_ID> /bin/bash
```

After you [Docker exec](http://docker.io) into the running container, your current directory is set to `/opt/app-root/src`, where the source code for your application is located.

### Using OpenShift's rsync

If you have deployed the container to OpenShift, you can use [oc rsync](https://docs.openshift.org/latest/dev_guide/copy_files_to_container.html) to copy local files to a remote container running in an OpenShift pod.

#### Warning:

The default behaviour of the s2i-nodejs docker image is to run the Node.js application using the command `npm start`. This runs the _start_ script in the _package.json_ file. In developer mode, the application is run using the command `nodemon`. The default behaviour of nodemon is to look for the _main_ attribute in the _package.json_ file, and execute that script. If the _main_ attribute doesn't appear in the _package.json_ file, it executes the _start_ script. So, in order to achieve some sort of uniform functionality between production and development modes, the user should remove the _main_ attribute.

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
Dockerfile for CentOS is called Dockerfile, Dockerfile for RHEL is called Dockerfile.rhel7.
