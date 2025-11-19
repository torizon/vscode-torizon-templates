# C++ Qt 6 QML Template Specific Documentation


> ⚠️ **WARNING:**  This is just the documentation part specific of this template. **For the complete and general Torizon IDE documentation, check the [developer website documentation](https://developer.toradex.com/torizon/application-development/ide-extension/)** ⚠️

All projects follow the pipeline of tasks described in the [common contributing documentation](https://github.com/toradex/vscode-torizon-templates/blob/bookworm/CONTRIBUTING.md#contributing-templates). However, each project has its own specificities in terms of technologies and methods used to compile, deploy, and debug the code. Therefore, each of them has their own specific tasks in the `tasks.json` file.

This C++ Qt 6 QML template uses `cmake` and `make` to compile the code, with tasks named `build-configure-\${architecture}` (creates the destination directory for the future compiled code and generates the Makefile, using `cmake`) and `build-debug-\${architecture}` (compiles the code). It also uses an SDK container to compile the code (through armhf and arm64 emulation). This container image is built using the `Dockerfile.sdk` file, and the tasks that build the containers are named `build-container-image-sdk-\${architecture}`.

The compiled code is then copied into the container, in the `torizon_app_root` (which is automatically passed to the `APP_ROOT` variable in the `Dockerfiles`) directory defined at `settings.json`, through the Docker `COPY` command.

The task that has the entire pipeline of executed tasks, from the first step to the last step before the debugging, is the `deploy-torizon-\${architecture}` task.

Finally, remote debugging is performed by attaching to the GDB on the running container on the device using a [VSCode feature called Pipe Transport](https://code.visualstudio.com/docs/cpp/pipe-transport). For local debugging, the [VSCode method for C/C++ Debugging](https://code.visualstudio.com/docs/cpp/launch-json-reference) is used. The tasks that perform the debugging are those present in the `launch.json` file.


The source code of the template is inspired by the one created using [the examples present on Qt Creator](https://doc.qt.io/qt-6/qtexamplesandtutorials.html), customizing it to a Torizon Qt QML (sort of Hello World) application. Also taking inspiration on examples present in the Qt documentation, like in the [CMake Build QML part](https://doc.qt.io/qt-6/cmake-build-qml-application.html).

## Qt Enterprise and Qt Open Source

To use Qt Enterprise, fill in the `qt_license_login` and `qt_license_password` settings. (To set them properly, remove these settings from `.vscode/settings.json`, then run the task `qt-enterprise-fill-license-login-password` in the **TASK RUNNER**.) To use Qt Open Source, simply leave those settings empty ("").

Also, when switching between Qt Enterprise and Qt Open Source modes, **remember to delete the `build-arm64` folder before starting a new debug session to ensure a clean build.**

To learn more about the differences between these modes and how each one works, refer to the [developer website documentation about Qt on Torizon OS](https://developer.toradex.com/torizon/application-development/use-cases/gui/qt-on-torizon-os).

Also, to request a free evaluation license, please got to: https://www.qt.io/qt-and-toradex


## Qt Creator and Qt Design Studio

You can open your application on Qt Creator and Qt Design Studio using the tasks `open-in-qt-creator` and `open-in-qt-design-studio`.

Also, it is possible to debug the application (including the QML part) on Qt Creator, through the task `start-gdb-server-\<remote or local>-\${architecture}`. This task performs the same steps as running the Remote Debugging (pressing `F5`) on VSCode, but instead of attaching to GDB like in VSCode it just runs the GDB server on the board in the end. To perform this form of debug, follow this steps:

 - Open the project on Qt Creator, through the `open-in-qt-creator-debug\${architecture}` task (`open-in-qt-creator` for local debug). It is necessary to open Qt Creator through this task.
 - Run the `start-gdb-server-\<remote or local>-\${architecture}` task. This task takes a while to run, and the message shown on the VSCode terminal when it is ready is `Listening port 2232`. You should wait for this message.

    ![](https://raw.githubusercontent.com/toradex/vscode-torizon-templates-documentation/bookworm/cppQML/startGDBServerTaskMessage.png)

 - On Qt Creator, `Attach to Running Debug Server` (or `Attach to QML Port` for debugging the QML):

    ![](https://raw.githubusercontent.com/toradex/vscode-torizon-templates-documentation/bookworm/cppQML/attachDebug.png)

 - Confirm the debugging information and press `Ok`:

    ![](https://raw.githubusercontent.com/toradex/vscode-torizon-templates-documentation/bookworm/cppQML/checkInfoAttachDebug.png)

## .gitignore and the .qt directory

For opening the project on Qt Creator it is necessary to have this `.qt` directory, with the initial files and folders present in it. So, you need to commit at least this initial `.qt` directory to your Git repository.

But literally almost anything you do on Qt Creator (like dragging the Qt Creator window for example) modifies this files, and this will be shown as modifications on Git. So, after you have committed the `.qt` file once, you can uncomment the `.qt` line from the `.gitignore` file.

