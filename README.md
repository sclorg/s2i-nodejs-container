NodeJS container images
====================

[![Build and push images to Quay.io registry](https://github.com/sclorg/s2i-nodejs-container/actions/workflows/build-and-push.yml/badge.svg)](https://github.com/sclorg/s2i-nodejs-container/actions/workflows/build-and-push.yml)

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
Currently supported versions are visible in the following table, expand an entry to see its container registry address.
<!--
Table start
-->
||CentOS Stream 9|CentOS Stream 10|Fedora|RHEL 8|RHEL 9|RHEL 10|
|:--|:--:|:--:|:--:|:--:|:--:|:--:|
|20|<details><summary>✓</summary>`quay.io/sclorg/nodejs-20-c9s`</details>|||<details><summary>✓</summary>`registry.redhat.io/rhel8/nodejs-20`</details>|<details><summary>✓</summary>`registry.redhat.io/rhel9/nodejs-20`</details>||
|20-minimal|<details><summary>✓</summary>`quay.io/sclorg/nodejs-20-minimal-c9s`</details>|||<details><summary>✓</summary>`registry.redhat.io/rhel8/nodejs-20-minimal`</details>|<details><summary>✓</summary>`registry.redhat.io/rhel9/nodejs-20-minimal`</details>||
|22||<details><summary>✓</summary>`quay.io/sclorg/nodejs-22-c10s`</details>||<details><summary>✓</summary>`registry.redhat.io/rhel8/nodejs-22`</details>|<details><summary>✓</summary>`registry.redhat.io/rhel9/nodejs-22`</details>|<details><summary>✓</summary>`registry.redhat.io/rhel10/nodejs-22`</details>|
|22-minimal||<details><summary>✓</summary>`quay.io/sclorg/nodejs-22-minimal-c10s`</details>||<details><summary>✓</summary>`registry.redhat.io/rhel8/nodejs-22-minimal`</details>|<details><summary>✓</summary>`registry.redhat.io/rhel9/nodejs-22-minimal`</details>|<details><summary>✓</summary>`registry.redhat.io/rhel10/nodejs-22-minimal`</details>|
|24|<details><summary>✓</summary>`quay.io/sclorg/nodejs-24-c9s`</details>|<details><summary>✓</summary>`quay.io/sclorg/nodejs-24-c10s`</details>|<details><summary>✓</summary>`quay.io/fedora/nodejs-24`</details>||<details><summary>✓</summary>`registry.redhat.io/rhel9/nodejs-24`</details>|<details><summary>✓</summary>`registry.redhat.io/rhel10/nodejs-24`</details>|
|24-minimal|<details><summary>✓</summary>`quay.io/sclorg/nodejs-24-minimal-c9s`</details>|<details><summary>✓</summary>`quay.io/sclorg/nodejs-24-minimal-c10s`</details>|<details><summary>✓</summary>`quay.io/fedora/nodejs-24-minimal`</details>||<details><summary>✓</summary>`registry.redhat.io/rhel9/nodejs-24-minimal`</details>|<details><summary>✓</summary>`registry.redhat.io/rhel10/nodejs-24-minimal`</details>|
<!--
Table end
-->

Installation
---------------
To build a Node.JS image, choose either the CentOS or RHEL based image:
*  **RHEL based image**

    These images are available in the [Red Hat Container Catalog](https://access.redhat.com/containers/#/registry.access.redhat.com/rhel8/nodejs-20).
    To download it run:

    ```
    $ podman pull registry.access.redhat.com/rhel8/nodejs-20
    ```

    To build a RHEL based Node.JS image, you need to run the build on a properly
    subscribed RHEL machine.

    ```
    $ git clone --recursive https://github.com/sclorg/s2i-nodejs-container.git
    $ cd s2i-nodejs-container
    $ git submodule update --init
    $ make build TARGET=rhel8 VERSIONS=20
    ```

*  **CentOS Stream based image**

    This image is available on DockerHub. To download it run:

    ```
    $ podman pull quay.io/sclorg/nodejs-20-c9s
    ```

    To build a Node.JS image from scratch run:

    ```
    $ git clone --recursive https://github.com/sclorg/s2i-nodejs-container.git
    $ cd s2i-nodejs-container
    $ git submodule update --init
    $ make build TARGET=c9s VERSIONS=20
    ```

Note: while the installation steps are calling `podman`, you can replace any such calls by `docker` with the same arguments.

**Notice: By omitting the `VERSIONS` parameter, the build/test action will be performed
on all provided versions of Node.JS.**


Usage
-----

For information about usage of Dockerfile for NodeJS 20,
see [usage documentation](20/README.md).

For information about usage of Dockerfile for NodeJS 20 minimal,
see [usage documentation](20-minimal/README.md).

For information about usage of Dockerfile for NodeJS 22,
see [usage documentation](22/README.md).

For information about usage of Dockerfile for NodeJS 22 minimal,
see [usage documentation](22-minimal/README.md).

For information about usage of Dockerfile for NodeJS 24,
see [usage documentation](24/README.md).

For information about usage of Dockerfile for NodeJS 24 minimal,
see [usage documentation](24-minimal/README.md).

Test
----
This repository also provides a [S2I](https://github.com/openshift/source-to-image) test framework,
which launches tests to check functionality of a simple Node.JS application built on top of the s2i-nodejs image.

Users can choose between testing a Node.JS test application based on a RHEL or CentOS Stream image.

*  **RHEL based image**

    To test a RHEL8 based Node.JS image, you need to run the test on a properly
    subscribed RHEL machine.

    ```
    $ cd s2i-nodejs-container
    $ git submodule update --init
    $ make test TARGET=rhel8 VERSIONS=20
    ```

*  **CentOS Stream based image**

    ```
    $ cd s2i-nodejs-container
    $ git submodule update --init
    $ make test TARGET=c9s VERSIONS=20
    ```

**Notice: By omitting the `VERSIONS` parameter, the build/test action will be performed
on all provided versions of Node.JS.**


Repository organization
------------------------
* **`<nodejs-version>`**

    * **Dockerfile.rhel8**

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

