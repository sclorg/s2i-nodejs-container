NodeJS for OpenShift - Docker images
========================================

This repository contains sources of the images for building various versions
of NodeJS applications as reproducible Docker images using
[source-to-image](https://github.com/openshift/source-to-image).
User can choose between RHEL and CentOS based builder images.
The resulting image can be run using [Docker](http://docker.io).


Versions
---------------
NodeJS versions currently supported are:
* nodejs-0.10

RHEL versions currently supported are:
* RHEL7

CentOS versions currently supported are:
* CentOS7


Installation
---------------
To build NodeJS image, choose between CentOS or RHEL based image:
*  **RHEL based image**
    This image is not available as trusted build in [Docker Index](https://index.docker.io).

    To build a rhel-based nodejs-0.10 image, you need to run the build on properly
    subscribed RHEL machine.

    ```
    $ git clone https://github.com/openshift/sti-nodejs.git
    $ cd sti-nodejs
    $ make build TARGET=rhel7 VERSION=0.10
    ```

*  **CentOS based image**
    ```
    $ git clone https://github.com/openshift/sti-nodejs.git
    $ cd sti-nodejs
    $ make build VERSION=0.10
    ```

**Notice: By omitting the `VERSION` parameter, the build/test action will be performed
on all the supported versions of NodeJS. Since we are now supporting only version `0.10`,
you can omit this parameter.**


Usage
---------------------
To build simple [nodejs-echo-app](https://github.com/ryanj/node-echo) application,
using standalone [STI](https://github.com/openshift/source-to-image) and then run the
resulting image with [Docker](http://docker.io) execute:

*  **For RHEL based image**
    ```
    $ sti build https://github.com/ryanj/node-echo.git openshift/nodejs-010-rhel7 nodejs-echo-app
    $ docker run -p 3000:3000 nodejs-echo-app
    ```

*  **For CentOS based image**
    ```
    $ sti build https://github.com/ryanj/node-echo.git openshift/nodejs-010-centos7 nodejs-echo-app
    $ docker run -p 3000:3000 nodejs-echo-app
    ```

**Accessing the application:**
```
$ curl 127.0.0.1:3000
```


Test
---------------------
This repository also provides [STI](https://github.com/openshift/source-to-image) test framework,
which launches tests to check functionality of a simple nodejs application built on top of sti-nodejs image.

User can choose between testing nodejs test application based on RHEL or CentOS image.

*  **RHEL based image**

    This image is not available as trusted build in [Docker Index](https://index.docker.io).

    To test a rhel7-based nodejs-0.10 image, you need to run the test on a properly
    subscribed RHEL machine.

    ```
    $ cd sti-nodejs
    $ make test TARGET=rhel7 VERSION=0.10
    ```

*  **CentOS based image**

    ```
    $ cd sti-nodejs
    $ make test VERSION=0.10
    ```

**Notice: By omitting the `VERSION` parameter, the build/test action will be performed
on all the supported versions of NodeJS. Since we are now supporting only version `0.10`
you can omit this parameter.**


Repository organization
------------------------
* **`<nodejs-version>`**

    * **Dockerfile**

        CentOS based Dockerfile.

    * **Dockerfile.rhel7**

        RHEL based Dockerfile. In order to perform build or test actions on this
        Dockerfile you need to run the action on properly subscribed RHEL machine.

    * **`.sti/bin/`**

        This folder contains scripts that are run by [STI](https://github.com/openshift/source-to-image):

        *   **assemble**

            Is used to install the sources into location from where the application
            will be run and prepare the application for deployment (eg. installing
            modules using npm, etc..)

        *   **run**

            This script is responsible for running the application, by using the
            application web server.

        *   **save-artifacts**

            In order to do an *incremental build* (iow. re-use the build artifacts
            from an already built image in a new image), this script is responsible for
            archiving those. In this image, this script will archive all dependent modules.

    * **`nodejs/`**

        This folder contains file with commonly used modules.

    * **`test/`**

        This folder is containing [STI](https://github.com/openshift/source-to-image)
        test framework with simple node.js echo server.

        * **`test-app/`**

            Simple node.js echo server for used for testing purposes in the [STI](https://github.com/openshift/source-to-image) test framework.

        * **run**

            Script that runs the [STI](https://github.com/openshift/source-to-image) test framework.

* **`hack/`**

    Folder contains scripts which are responsible for build and test actions performed by the `Makefile`.

Image name structure
------------------------
##### Structure: openshift/1-2-3

1. Platform name - nodejs
2. Platform version(without dots)
3. Base builder image - centos7/rhel7

Examples: `openshift/nodejs-010-centos7`, `openshift/nodejs-010-rhel7`


Environment variables
---------------------

*  **STI_SCRIPTS_URL** (default: [`.sti/bin`](https://raw.githubusercontent.com/openshift/sti-nodejs/master/0.10/.sti/bin))

    This variable specifies the location of directory, where *assemble*, *run* and
    *save-artifacts* scripts are downloaded/copied from. By default the scripts
    in this repository will be used, but users can provide an alternative
    location and run their own scripts (see [sti build](https://github.com/openshift/source-to-image/blob/master/docs/cli.md#sti-build)).

* **STI_LOCATION** (default: `/tmp`)

    This variable specifies existing directory inside the builder image where
    the scripts and sources will be placed before executing *assemble* script.
    By default `/tmp` is used and *assemble* script expects sources and scripts
    to be present there, but users can provide an alternative location
    (see [sti build](https://github.com/openshift/source-to-image/blob/master/docs/cli.md#sti-build)).
