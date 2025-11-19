# ASP.NET 8 Blazor Template Specific Documentation


> ⚠️ **WARNING:**  This is just the documentation part specific of this template. **For the complete and general Torizon IDE documentation, check the [developer website documentation](https://developer.toradex.com/torizon/application-development/ide-extension/)** ⚠️

All projects follow the pipeline of tasks described in the [common contributing documentation](https://github.com/toradex/vscode-torizon-templates/blob/bookworm/CONTRIBUTING.md#contributing-templates). However, each project has its own specificities in terms of technologies and methods used to compile, deploy, and debug the code. Therefore, each of them has their own specific tasks in the **tasks.json** file.

This .NET C# console template uses **dotnet publish** CLI command to compile the source code and create a deployable package, with tasks named **publish-torizon-\${architecture}**. However, for local debugging it is not necessary to create a deployable package so just the **dotnet build** task is enough in this case(please note that the **preLaunchTask** of local debug is **build-application-local** and not **publish-application-local**, but the publish local task is there just for you to use if for any specific reason you need this local publish).

For .NET templates it is important to point out that they do not use the torizon base containers (torizon/debian, torizon/wayland-base, torizon/wayland-base-vivante, etc.). Instead, they use custom **dotnet**, **aspdotnet** and **dotnet-uno** containers, which are based on the base containers but also contain the appropriate .NET runtime (and debugger for debug images) and some necessary dependencies to execute the code. Therefore, the **--no-self-contained** argument can be passed to the **dotnet publish** command to not compile and ship also the .NET runtime to the remote container.

The deployable package is then copied into the running debug container using **scp**, in the task named **deploy-torizon-\${architecture}**. This task contains the entire sequence of tasks executed by the pipeline and, therefore, is unique to each template.

Finally, remote debugging is performed by attaching to the Visual Studio Debugger (vsdbg) on the running container on the device using a [VSCode feature called Pipe Transport](https://code.visualstudio.com/docs/cpp/pipe-transport). For local debugging, the method used is the one described in the [VSCode documentation for .NET Debugging](https://learn.microsoft.com/en-us/dotnet/core/tutorials/debugging-with-visual-studio-code?pivots=dotnet-8-0) is used. The tasks that perform the debugging are those present in the **launch.json** file.

The source code of the template is inspired by the one created following the [instructions from the VSCode Blazor app creation](https://dotnet.microsoft.com/en-us/learn/aspnet/blazor-tutorial/create) (without including the **obj** folder and without passing the **--no-https** and **-f net7.0** arguments. Also, the ports numbers on the **launchSettings.json** file, inside the **Properties** directory, were modified).

> ⚠️ **WARNING**: although the template is created with the `-f net7.0` argument, the target framework used in `.csproj` is `net8.0`. In .NET 8 the Blazor template is an unified web app with options to run it on the server or on the client with WebAssembly. Since the Blazor Server template will continue to be supported in .NET 8, we considered just update the template from .NET 7 and bump the target framework. For further information, please refer to the [New Blazor Web App template](https://learn.microsoft.com/en-us/aspnet/core/release-notes/aspnetcore-8.0?view=aspnetcore-7.0#new-blazor-web-app-template). If you need new features from the new Blazor Web App template please reach to us with your use case and we will consider to add a new template.

## Running Blazor GUI in Kiosk Mode

The Blazor is a web application that needs a browser to show the GUI. If you want to show the GUI in a screen connected to the board you can launch the `Torizon Browser ARMv8` debug session. This will run the Blazor application and also a [Cog](https://github.com/Igalia/cog) browser to open the GUI in the board connected screen.

The Docker compose service to run for production that has the Cog browser is `__change__-browser`.
