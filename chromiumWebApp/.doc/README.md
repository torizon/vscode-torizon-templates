# Chromium Web App Template Specific Documentation

> ⚠️ **WARNING:**  This is just the documentation part specific of this template. **For the complete and general Torizon IDE documentation, check the [developer website documentation](https://developer.toradex.com/torizon/application-development/ide-extension/)** ⚠️

All projects follow the pipeline of tasks described in the [common contributing documentation](https://github.com/toradex/vscode-torizon-templates/blob/bookworm/CONTRIBUTING.md#contributing-templates). However, each project has its own specificities in terms of technologies and methods used to compile, deploy, and debug the code. Therefore, each of them has their own specific tasks in the **tasks.json** file.

This Chromium Web App template is built using the Torizon **torizon/chromium** base container, which includes Chromium browser and necessary dependencies for running web-based applications on the device. The template provides a simple HTML/JavaScript web application that runs in a containerized Chromium environment.

The application files (HTML, CSS, and JavaScript) are copied into the container at the `torizon_app_root` directory (which is automatically passed to the `APP_ROOT` variable in the `Dockerfile`), as defined in `settings.json`, through the Docker `COPY` command.

The task that has the entire pipeline of executed tasks, from building the container image to deploying it on the device, is the `deploy-torizon-${architecture}` task. This template includes remote debugging configurations in `launch.json` that attach to Chromium via CDP over an SSH tunnel.

The source code of the template is a simple Hello Torizon web application consisting of:
- **index.html** - Main HTML file that serves as the entry point for your web application. If you move or rename this file, you must also update any references to `index.html` in the template configuration and deployment files.
- **app.js** - JavaScript file with simple application logic
- **style.css** - Stylesheet for application styling

## Using This Template

This template supports two workflows for running your Chromium web application:

### For Production Services

To build and deploy the container for production use, run the `run-container-torizon-release-<arch>` task (where `<arch>` is one of: arm64, arm, or amd64).

To run this task, click on the `Explorer` icon on the VSCode Activity bar (first icon on the vertical bar on the left of the VSCode screen), open the `TASK RUNNER` tab and then click on the task.

### For Development and Debugging

For development and debugging purposes, use the **Run and Debug** tab in VSCode (press `Ctrl+Shift+D` or click the debug icon on the Activity bar). The debugging configuration options are defined in the `launch.json` file and will allow you to test your application with debugging capabilities enabled.

## Remote Debugging

Remote debugging is performed by establishing an SSH tunnel to the running Chromium container on the device and connecting to Chromium's built-in debug port. The SSH tunnel approach is necessary because Chromium's `--remote-debugging-address` argument, which would allow binding to the device's IP address for network access, requires the `--headless` flag to function. Since headless mode prevents any visual rendering, which is essential for a web application, the SSH tunnel provides a secure alternative that forwards the debug protocol over the network connection without requiring Chromium to run in headless mode. The debugging configuration for remote connections is defined in the `launch.json` file, and the tasks that manage the debugging process are initiated when you select a debug configuration from the **Run and Debug** tab.

> If breakpoints are not being hit during a debug session, the debugger may be attaching before the page finishes loading. Increase the `wait_sync` value in `settings.json` to give the browser more time to be ready before the debugger connects.

## Local Debugging

Opens your application directly from the project files using a `file://` URL. This is the fastest way to test your application locally without needing any infrastructure. Simply select the "Local Debug" configuration and press `F5` to launch your application in the browser.

## Customizing the Web Application

### Modifying the HTML/CSS/JavaScript

Simply edit the files in the `src/` directory:
- Update `index.html` for the page structure. If you move or rename this file, also update any references to `index.html` in the template configuration, deployment files, and debugging settings.
- Update `style.css` for styling
- Update `app.js` for application logic

After modifying the application files, run the `deploy-torizon-<arch>` task again to rebuild the container and deploy the updated application to the device.

## Application Runtime in Container

The Chromium container provides a full graphical environment with necessary dependencies pre-installed. The `docker-compose.yml` configures the required permissions, volumes, and environment variables for Chromium to run properly on the device, including:
- Display and input device access
- D-Bus socket for system communication
- Shared memory for Chromium processes
- Device access for GPU and input handling
