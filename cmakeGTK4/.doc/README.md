# C++ CMake GTK 4 Template Specific Documentation

> ⚠️ **WARNING:**  This is just the documentation part specific of this template. **For the complete and general Torizon IDE documentation, check the [developer website documentation](https://developer.toradex.com/torizon/application-development/ide-extension/)** ⚠️

All projects follow the pipeline of tasks described in the [common contributing documentation](https://github.com/toradex/vscode-torizon-templates/blob/bookworm/CONTRIBUTING.md#contributing-templates). However, each project has its own specificities in terms of technologies and methods used to compile, deploy, and debug the code. Therefore, each of them has their own specific tasks in the `tasks.json` file.

This C++ GTK 4 template uses `cmake` and `make` to compile the code, with tasks named `build-configure-\${architecture}` (creates the destination directory for the future compiled code and generates the Makefile, using `cmake`) and `build-debug-\${architecture}` (compiles the code). It also uses an SDK container to cross-compile the code. This container image is built using the `Dockerfile.sdk` file, and the tasks that build the containers are named `build-container-image-sdk-\${architecture}`.

The compiled code is then copied into the container, in the `torizon_app_root` (which is automatically passed to the `APP_ROOT` variable in the `Dockerfiles`) directory defined at `settings.json`, through the Docker `COPY` command.

The task that has the entire pipeline of executed tasks, from the first step to the last step before the debugging, is the `deploy-torizon-\${architecture}` task.

Finally, remote debugging is performed by attaching to the GDB on the running container on the device using a [VSCode feature called Pipe Transport](https://code.visualstudio.com/docs/cpp/pipe-transport). For local debugging, the [VSCode method for C/C++ Debugging](https://code.visualstudio.com/docs/cpp/launch-json-reference) is used. The tasks that perform the debugging are those present in the `launch.json` file.

The source code of the template is a simple GTK 3 Hello World (Hello Torizon, actually) in C++, using CMake as build system.

## About GTK 4

To learn or use GTK 4, you must refer to the official [GTK 4 Documentation](https://www.gtk.org/docs/).
