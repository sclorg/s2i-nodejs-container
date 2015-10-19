NodeJS Docker image
===================

This repository contains the source for building various versions of
the Node.JS application as a reproducible Docker image using
[source-to-image](https://github.com/openshift/source-to-image).
Users can choose between RHEL and CentOS based builder images.
The resulting image can be run using [Docker](http://docker.io).


Usage
---------------------
To build a simple [nodejs-sample-app](https://github.com/openshift/sti-nodejs/tree/master/0.10/test/test-app) application
using standalone [STI](https://github.com/openshift/source-to-image) and then run the
resulting image with [Docker](http://docker.io) execute:

*  **For RHEL based image**
    ```
    $ s2i build https://github.com/openshift/sti-nodejs.git --context-dir=0.10/test/test-app/ openshift/nodejs-010-rhel7 nodejs-sample-app
    $ docker run -p 8080:8080 nodejs-sample-app
    ```

*  **For CentOS based image**
    ```
    $ s2i build https://github.com/openshift/sti-nodejs.git --context-dir=0.10/test/test-app/ openshift/nodejs-010-centos7 nodejs-sample-app
    $ docker run -p 8080:8080 nodejs-sample-app
    ```

**Accessing the application:**
```
$ curl 127.0.0.1:8080
```


Repository organization
------------------------
* **`<nodejs-version>`**

    * **Dockerfile**

        CentOS based Dockerfile.

    * **Dockerfile.rhel7**

        RHEL based Dockerfile. In order to perform build or test actions on this
        Dockerfile you need to run the action on a properly subscribed RHEL machine.

    * **`s2i/bin/`**

        This folder contains scripts that are run by [STI](https://github.com/openshift/source-to-image):

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


Environment variables
---------------------

To set environment variables, you can place them as a key value pair into a `.sti/environment`
file inside your source code repository.

Example: DATABASE_USER=sampleUser

Hot deploy
---------------------
Hot deploy is not supported in this image. To support it, make sure that modules responsible for the server reload are installed upon the build process. Those modules are:

* [Supervisor](https://github.com/petruisfan/node-supervisor)
* [Nodemon](https://github.com/remy/nodemon)

Please note that in order to be able to run your application in development mode, you need to modify the [S2I run script](https://github.com/openshift/source-to-image#anatomy-of-a-builder-image), so the web server is launched by the chosen module, which checks for changes in the source code.

To change your source code in running container, use Docker's [exec](http://docker.io) command:
```
docker exec -it <CONTAINER_ID> /bin/bash
```

After you [Docker exec](http://docker.io) into the running container, your current directory is set to `/opt/app-root/src`, where the source code is located.
