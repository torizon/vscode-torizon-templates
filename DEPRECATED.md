# Deprecated templates

| TEMPLATE | DESCRIPTION | RUNTIME | LANGUAGE | HW ARCH | FOLDER | CONTRIBUTOR |
| -------- | ----------- | ------- | -------- | ------- | ------ | ----------- |
| ![](https://raw.githubusercontent.com/toradex/vscode-torizon-templates-documentation/refs/heads/main/thumbnails/unogtk.png?raw=true) | .NET 6 C# Uno Platform Skia.GTK | .NET 6.0 | C# | ![](assets/img/arm32.png?raw=true&id=2) ![](assets/img/arm64.png?raw=true&id=2)   | [dotnetUno](./dotnetUno) | ![](https://avatars.githubusercontent.com/u/2633321?v=4&s=64&s=64) [@microhobby](https://www.github.com/microhobby) |
| ![](https://raw.githubusercontent.com/toradex/vscode-torizon-templates-documentation/refs/heads/main/thumbnails/unofbdrm.png?raw=true) | .NET 6 C# Uno Platform Frame Buffer | .NET 6.0 | C# | ![](assets/img/arm32.png?raw=true&id=2) ![](assets/img/arm64.png?raw=true&id=2) | [dotnetUnoFrameBuffer](./dotnetUnoFrameBuffer) | ![](https://avatars.githubusercontent.com/u/2633321?v=4&s=64) [@microhobby](https://www.github.com/microhobby) |

Due to the eminent EOL of .NET 6, .NET 6 Uno and .NET 6 Uno FrameBuffer templates are deprecated, being replaced by the [.NET 8 Uno 5](./dotnetUno5) and [.NET 8 Uno 5 FrameBuffer](./dotnetUno5FrameBuffer) templates.

Due to the quite big difference between .NET 6 Uno 4 and .NET 8 Uno 5, it is not possible to update the project via `try-update-template` task. To update it, create a new .NET 8 Uno 5 clean project and update the source files accordingly.
