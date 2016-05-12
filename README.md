NodeJS Docker images
====================

This repository contains the source for building various versions of
the Node.JS application as a reproducible Docker image using
[source-to-image](https://github.com/openshift/source-to-image).
Users can choose between RHEL and CentOS based builder images.
The resulting image can be run using [Docker](http://docker.io).

For more information about using these images with OpenShift, please see the
official [OpenShift Documentation](https://docs.openshift.org/latest/using_images/s2i_images/nodejs.html).


Versions
---------------
Node.JS versions currently provided are:
* nodejs-0.10

RHEL versions currently supported are:
* RHEL7

CentOS versions currently supported are:
* CentOS7


Installation
---------------
To build a Node.JS image, choose either the CentOS or RHEL based image:
*  **RHEL based image**

    To build a RHEL based Node.JS-0.10 image, you need to run the build on a properly
    subscribed RHEL machine.

    ```
    $ git clone https://github.com/openshift/s2i-nodejs.git
    $ cd s2i-nodejs
    $ make build TARGET=rhel7 VERSION=0.10
    ```

*  **CentOS based image**

    This image is available on DockerHub. To download it run:

    ```
    $ docker pull openshift/nodejs-010-centos7
    ```

    To build a Node.JS image from scratch run:

    ```
    $ git clone https://github.com/openshift/s2i-nodejs.git
    $ cd s2i-nodejs
    $ make build VERSION=0.10
    ```

**Notice: By omitting the `VERSION` parameter, the build/test action will be performed
on all provided versions of Node.JS. Since we are currently providing only version `0.10`,
you can omit this parameter.**


Usage
---------------------------------

For information about usage of Dockerfile for NodeJS 0.10,
see [usage documentation](0.10/README.md).


Test
---------------------
This repository also provides a [S2I](https://github.com/openshift/source-to-image) test framework,
which launches tests to check functionality of a simple Node.JS application built on top of the s2i-nodejs image.

Users can choose between testing a Node.JS test application based on a RHEL or CentOS image.

*  **RHEL based image**

    To test a RHEL7 based Node.JS-0.10 image, you need to run the test on a properly
    subscribed RHEL machine.

    ```
    $ cd s2i-nodejs
    $ make test TARGET=rhel7 VERSION=0.10
    ```

*  **CentOS based image**

    ```
    $ cd s2i-nodejs
    $ make test VERSION=0.10
    ```

**Notice: By omitting the `VERSION` parameter, the build/test action will be performed
on all provided versions of Node.JS. Since we are currently providing only version `0.10`
you can omit this parameter.**


Repository organization
------------------------
* **`<nodejs-version>`**

    Dockerfile and scripts to build container images from.

* **`hack/`**

    Folder containing scripts which are responsible for the build and test actions performed by the `Makefile`.


Image name structure
------------------------
##### Structure: openshift/1-2-3

1. Platform name (lowercase) - nodejs
2. Platform version(without dots) - 010
3. Base builder image - centos7/rhel7

Examples: `openshift/nodejs-010-centos7`, `openshift/nodejs-010-rhel7`

