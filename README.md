NodeJS container images
====================

[![Build and push images to Quay.io registry](https://github.com/sclorg/s2i-nodejs-container/actions/workflows/build-and-push.yml/badge.svg)](https://github.com/sclorg/s2i-nodejs-container/actions/workflows/build-and-push.yml)

Images available on Quay are:
* CentOS 7 [nodejs-12](https://quay.io/repository/centos7/nodejs-12-centos7)
* CentOS 7 [nodejs-14](https://quay.io/repository/centos7/nodejs-14-centos7)
* CentOS Stream 9 [nodejs-16](https://quay.io/repository/sclorg/nodejs-16-c9s)
* Fedora [nodejs-14](https://quay.io/repository/fedora/nodejs-14)
* Fedora [nodejs-16](https://quay.io/repository/fedora/nodejs-16)


This repository contains the source for building various versions of
the Node.JS application as a reproducible container image using
[source-to-image](https://github.com/openshift/source-to-image).
Users can choose between RHEL, CentOS and Fedora based builder images.
The resulting image can be run using [podman](https://github.com/containers/libpod).

For more information about using these images with OpenShift, please see the
official [OpenShift Documentation](https://docs.okd.io/latest/using_images/s2i_images/nodejs.html).

For more information about contributing, see
[the Contribution Guidelines](https://github.com/sclorg/welcome/blob/master/contribution.md).
For more information about concepts used in these container images, see the
[Landing page](https://github.com/sclorg/welcome).


Versions
---------------
Node.JS versions currently provided are:
* [NodeJS 14](14)
* [NodeJS 16](16)

RHEL versions currently supported are:
* RHEL7
* RHEL8
* RHEL9

CentOS versions currently supported are:
* CentOS7
* CentOS Stream 9


Installation
---------------
To build a Node.JS image, choose either the CentOS or RHEL based image:
*  **RHEL based image**

    These images are available in the [Red Hat Container Catalog](https://access.redhat.com/containers/#/registry.access.redhat.com/rhscl/nodejs-16-rhel7).
    To download it run:

    ```
    $ podman pull registry.access.redhat.com/rhscl/nodejs-16-rhel7
    ```

    To build a RHEL based Node.JS image, you need to run the build on a properly
    subscribed RHEL machine.

    ```
    $ git clone --recursive https://github.com/sclorg/s2i-nodejs-container.git
    $ cd s2i-nodejs-container
    $ git submodule update --init
    $ make build TARGET=rhel7 VERSIONS=16
    ```

*  **CentOS based image**

    This image is available on DockerHub. To download it run:

    ```
    $ podman pull quay.io/centos7/nodejs-16-centos7
    ```

    To build a Node.JS image from scratch run:

    ```
    $ git clone --recursive https://github.com/sclorg/s2i-nodejs-container.git
    $ cd s2i-nodejs-container
    $ git submodule update --init
    $ make build TARGET=centos7 VERSIONS=16
    ```

Note: while the installation steps are calling `podman`, you can replace any such calls by `docker` with the same arguments.

**Notice: By omitting the `VERSIONS` parameter, the build/test action will be performed
on all provided versions of Node.JS.**


Usage
-----

For information about usage of Dockerfile for NodeJS 14,
see [usage documentation](14/README.md).

For information about usage of Dockerfile for NodeJS 16,
see [usage documentation](16/README.md).

Test
----
This repository also provides a [S2I](https://github.com/openshift/source-to-image) test framework,
which launches tests to check functionality of a simple Node.JS application built on top of the s2i-nodejs image.

Users can choose between testing a Node.JS test application based on a RHEL or CentOS image.

*  **RHEL based image**

    To test a RHEL7 based Node.JS image, you need to run the test on a properly
    subscribed RHEL machine.

    ```
    $ cd s2i-nodejs-container
    $ git submodule update --init
    $ make test TARGET=rhel7 VERSIONS=16
    ```

*  **CentOS based image**

    ```
    $ cd s2i-nodejs-container
    $ git submodule update --init
    $ make test TARGET=centos7 VERSIONS=16
    ```

**Notice: By omitting the `VERSIONS` parameter, the build/test action will be performed
on all provided versions of Node.JS.**


Repository organization
------------------------
* **`<nodejs-version>`**

    * **Dockerfile**

        CentOS based Dockerfile.

    * **Dockerfile.rhel7**

        RHEL based Dockerfile. In order to perform build or test actions on this
        Dockerfile you need to run the action on a properly subscribed RHEL machine.

    * **`s2i/bin/`**

        This folder contains scripts that are run by [S2I](https://github.com/openshift/source-to-image):

        *   **assemble**

            Used to install the sources into the location where the application
            will be run and prepare the application for deployment (eg. installing
            modules using npm, etc.)

        *   **run**

            This script is responsible for running the application, by using the
            application web server.

        *   **usage***

            This script prints the usage of this image.

    * **`contrib/`**

        This folder contains a file with commonly used modules.

    * **`test/`**

        This folder contains the [S2I](https://github.com/openshift/source-to-image)
        test framework with simple Node.JS echo server.

        * **`test-app/`**

            A simple Node.JS echo server used for testing purposes by the [S2I](https://github.com/openshift/source-to-image) test framework.

        * **run**

            This script runs the [S2I](https://github.com/openshift/source-to-image) test framework.

