# Node.js TypeScript Template Specific Documentation


> ⚠️ **WARNING:**  This is just the documentation part specific of this template. **For the complete and general Torizon IDE documentation, check the [developer website documentation](https://developer.toradex.com/torizon/application-development/ide-extension/)** ⚠️

All projects follow the pipeline of tasks described in the [common contributing documentation](https://github.com/toradex/vscode-torizon-templates/blob/bookworm/CONTRIBUTING.md#contributing-templates). However, each project has its own specificities in terms of technologies and methods used to compile, deploy, and debug the code. Therefore, each of them has their own specific tasks in the **tasks.json** file.

This Node.js TypeScript template uses `npm run <script>` to compile (using **tsc**) and install the code in the **out** directory, with tasks named **build-typescript-\${architecture}**.

The compiled code is then copied into the running debug container using **scp**, in the task named **deploy-torizon-\${architecture}**. This task contains the entire sequence of tasks executed by the pipeline and, therefore, is unique to each template.

Remote debugging is performed by running `node --inspect-brk=0.0.0.0:<port> <app-dir>` inside the running container on the device, in a task named **start-torizon-debug\${architecture}**, and then attaching to this running container, similar to the explanation in [VSCode documentation for attaching to Node.js](https://code.visualstudio.com/docs/nodejs/nodejs-debugging#_attaching-to-nodejs). For local debugging, the method used is the one described in the [VSCode documentation for TypeScript Debugging](https://code.visualstudio.com/docs/typescript/typescript-debugging) is used. The tasks that perform the debugging are those present in the **launch.json** file.

The source code of the template is a simple Hello World (Hello Torizon, actually) in Typescript.

## npm-install task ##

To avoid running `npm install` on the host every time you want to debug your code, the **npm-install** task runs the `npm install` command on the host only when there is no **node_modules** file. Therefore, every time you want to update your node modules you need to run the `npm install` command on the terminal, or also you can modify the **npm-install** task to run the command when you want.
