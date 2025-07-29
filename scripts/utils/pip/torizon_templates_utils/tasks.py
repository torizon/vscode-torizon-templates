"""Task utilities for VS Code tasks.json handling."""

import inspect
import json
import mimetypes
import os
import re
import subprocess
from pathlib import Path
from typing import Dict, List, Literal, Optional, Type, TypeVar, Union

import yaml  # type: ignore[import-untyped]

from .colors import Color, cprint
from .network import is_in_docker_container

print = cprint  # pylint: disable=redefined-builtin

T = TypeVar("T")


def replace_tasks_input():
    """Replaces deprecated input keys in tasks with their new command equivalents."""
    for file in Path(".").rglob("*.json"):
        print(file, flush=True)
        mime_type, _ = mimetypes.guess_type(file)

        if mime_type is None or mime_type.startswith("application/octet-stream"):
            if "id_rsa" not in str(file):
                with open(file, "r", encoding="utf-8") as f:
                    content = f.read()

                content = content.replace("input:dockerLogin", "command:docker_login")
                content = content.replace("input:dockerImageRegistry", "command:docker_registry")
                content = content.replace("input:dockerPsswd", "command:docker_password")

                with open(file, "w", encoding="utf-8") as f:
                    f.write(content)


def _cast_from_json(json_data, cls: Type[T]) -> T:
    # work on a copy
    data = dict(json_data)

    # normalize keys like "name.prop" -> "name_prop"
    for k in list(data.keys()):
        if "." in k:
            data[k.replace(".", "_")] = data.pop(k)

    # alias common JSON keys to our constructor parameter names
    sig = inspect.signature(cls.__init__).parameters
    if "task_type" in sig and "type" in data:
        data["task_type"] = data.pop("type")
    if "input_id" in sig and "id" in data:
        data["input_id"] = data.pop("id")
    if "icon_id" in sig and "id" in data:
        data["icon_id"] = data.pop("id")

    expected_args = sig.keys()
    filtered = {k: v for k, v in data.items() if k in expected_args}

    # capture non-expected args into extra_settings when available
    if "extra_settings" in expected_args:
        extra = {k: v for k, v in data.items() if k not in expected_args}
        filtered["extra_settings"] = extra

    return cls(**filtered)


# For Settings interface we are mapping only the Torizon specific settings
class TorizonSettings:  # pylint: disable=too-few-public-methods
    """
    TorizonSettings is an interface to map specific VS Code settings defined
    by the Torizon extension.
    """

    _ATTRS = [
        "torizon_psswd", "torizon_login", "torizon_ip", "torizon_ssh_port", "host_ip",
        "torizon_workspace", "torizon_debug_ssh_port", "torizon_debug_ports", "torizon_gpu",
        "torizon_arch", "wait_sync", "torizon_run_as", "torizon_app_root", "docker_tag",
        "tcb_package_name", "tcb_version", "torizon_gpu_prefix_rc"
    ]

    def __init__(  # pylint: disable=too-many-arguments, too-many-positional-arguments, too-many-locals
        self,
        torizon_psswd: Optional[str] = None,
        torizon_login: Optional[str] = None,
        torizon_ip: Optional[str] = None,
        torizon_ssh_port: Optional[str] = None,
        host_ip: Optional[str] = None,
        torizon_workspace: Optional[str] = None,
        torizon_debug_ssh_port: Optional[str] = None,
        torizon_debug_ports: Optional[List[str]] = None,
        torizon_gpu: Optional[str] = None,
        torizon_arch: Optional[str] = None,
        wait_sync: Optional[str] = None,
        torizon_run_as: Optional[str] = None,
        torizon_app_root: Optional[str] = None,
        docker_tag: Optional[str] = None,
        tcb_package_name: Optional[str] = None,
        tcb_version: Optional[str] = None,
        torizon_gpu_prefix_rc: Optional[str] = None,
        extra_settings: Optional[Dict[str, str]] = None,
    ):
        self._settings = {
            "torizon_psswd": torizon_psswd,
            "torizon_login": torizon_login,
            "torizon_ip": torizon_ip,
            "torizon_ssh_port": torizon_ssh_port,
            "host_ip": host_ip,
            "torizon_workspace": torizon_workspace,
            "torizon_debug_ssh_port": torizon_debug_ssh_port,
            "torizon_debug_ports": torizon_debug_ports or [],
            "torizon_gpu": torizon_gpu,
            "torizon_arch": torizon_arch,
            "wait_sync": wait_sync,
            "torizon_run_as": torizon_run_as,
            "torizon_app_root": torizon_app_root,
            "docker_tag": docker_tag,
            "tcb_package_name": tcb_package_name,
            "tcb_version": tcb_version,
            "torizon_gpu_prefix_rc": torizon_gpu_prefix_rc,
        }
        self.extra_settings = extra_settings

    def get_setting(self, key: str) -> Optional[str]:
        """Get a setting value by key."""
        return self._settings.get(key, None)

    def to_dict(self) -> Dict[str, Optional[str]]:
        """Return settings as a dictionary."""
        result = dict(self._settings)
        if self.extra_settings:
            result["extra_settings"] = self.extra_settings
        return result

    def update_setting(self, key: str, value: Optional[str]) -> None:
        """Update a setting value by key."""
        if key in self._settings:
            self._settings[key] = value

    def list_settings(self) -> List[str]:
        """List all available setting keys."""
        return list(self._settings.keys())


# These are from:
class ShellConfiguration:  # pylint: disable=too-few-public-methods
    """ShellConfiguration defines the shell configuration for a task."""

    def __init__(self, executable: str, args: Optional[List[str]]):
        self.executable = executable
        self.args = args

    def get_executable(self) -> str:
        """Return the shell executable."""
        return self.executable


class CommandOptions:  # pylint: disable=too-few-public-methods
    """CommandOptions defines the command options for a task."""

    def __init__(  # pylint: disable=too-many-arguments, too-many-positional-arguments
        self,
        cwd: Optional[str] = None,
        env: Optional[Dict[str, str]] = None,
        shell: Optional[ShellConfiguration] = None,
    ):
        self.cwd = cwd
        self.env = env
        self.shell = _cast_from_json(shell, ShellConfiguration) if shell else None

    def get_cwd(self) -> Optional[str]:
        """Return the working directory."""
        return self.cwd

    def get_env(self) -> Optional[Dict[str, str]]:
        """Return the environment variables."""
        return self.env


class PresentationOptions:  # pylint: disable=too-few-public-methods
    """PresentationOptions defines the presentation options for a task."""

    def __init__(  # pylint: disable=too-many-arguments, too-many-positional-arguments
        self,
        reveal: Optional[Literal["never", "silent", "always"]] = None,
        echo: Optional[bool] = None,
        focus: Optional[bool] = None,
        panel: Optional[Literal["shared", "dedicated", "new"]] = None,
        show_reuse_message: Optional[bool] = None,
        clear: Optional[bool] = None,
        group: Optional[str] = None,
    ):
        self.reveal = reveal
        self.echo = echo
        self.focus = focus
        self.panel = panel
        self.show_reuse_message = show_reuse_message
        self.clear = clear
        self.group = group

    def to_dict(self) -> Dict[str, Optional[str]]:
        """Return presentation options as a dictionary."""
        return {
            "reveal": self.reveal,
            "echo": self.echo,
            "focus": self.focus,
            "panel": self.panel,
            "show_reuse_message": self.show_reuse_message,
            "clear": self.clear,
            "group": self.group,
        }


class ProblemPattern:  # pylint: disable=too-few-public-methods, too-many-instance-attributes
    """ProblemPattern defines the problem pattern for a task."""

    def __init__(  # pylint: disable=too-many-arguments, too-many-positional-arguments
        self,
        regexp: str,
        kind: Optional[Literal["file", "location"]] = None,
        file: Union[int, float] = 0,
        location: Optional[Union[int, float]] = None,
        line: Optional[Union[int, float]] = None,
        column: Optional[Union[int, float]] = None,
        end_line: Optional[Union[int, float]] = None,
        end_column: Optional[Union[int, float]] = None,
        severity: Optional[Union[int, float]] = None,
        code: Optional[Union[int, float]] = None,
        message: Union[int, float] = 0,
        loop: Optional[bool] = False,
    ):
        self.regexp = regexp
        self.kind = kind
        self.file = file
        self.location = location
        self.line = line
        self.column = column
        self.end_line = end_line
        self.end_column = end_column
        self.severity = severity
        self.code = code
        self.message = message
        self.loop = loop

    def to_dict(self) -> Dict[str, Union[str, int, float, bool, None]]:
        """Return problem pattern as a dictionary."""
        return {
            "regexp": self.regexp,
            "kind": self.kind,
            "file": self.file,
            "location": self.location,
            "line": self.line,
            "column": self.column,
            "end_line": self.end_line,
            "end_column": self.end_column,
            "severity": self.severity,
            "code": self.code,
            "message": self.message,
            "loop": self.loop,
        }


class BackgroundMatcher:  # pylint: disable=too-few-public-methods
    """BackgroundMatcher defines the background matcher for a task."""
    def __init__(
        self,
        active_on_start: Optional[bool] = False,
        begins_pattern: Optional[str] = None,
        ends_pattern: Optional[str] = None,
    ):
        self.active_on_start = active_on_start
        self.begins_pattern = begins_pattern
        self.ends_pattern = ends_pattern


    def is_active(self) -> bool:
        """Return whether the matcher is active on start."""
        return bool(self.active_on_start)


class ProblemMatcher:
    """ProblemMatcher defines the problem matcher for a task."""
    def __init__(  # pylint: disable=too-many-arguments, too-many-positional-arguments
        self,
        base: Optional[str] = None,
        owner: Optional[str] = "external",
        source: Optional[str] = None,
        severity: Optional[Literal["error", "warning", "info"]] = "error",
        file_location: Optional[
            str | List[str] | List[Union[Literal["search"], Dict[str, Optional[List[str]]]]]
        ] = None,
        pattern: Optional[str | ProblemPattern | List[ProblemPattern]] = None,
        background: Optional[BackgroundMatcher] = None,
    ):
        self.base = base
        self.owner = owner
        self.source = source
        self.severity = severity
        self.file_location = file_location
        self.pattern = _cast_from_json(pattern, ProblemPattern) if pattern else None
        self.background = _cast_from_json(background, BackgroundMatcher) if background else None


    def to_dict(self) -> Dict[str, object]:
        """Return a JSON-serializable dict."""
        def _maybe_dict(x):
            if isinstance(x, list):
                return [i.__dict__ if hasattr(i, "__dict__") else i for i in x]
            return x.__dict__ if hasattr(x, "__dict__") else x

        return {
            "base": self.base,
            "owner": self.owner,
            "source": self.source,
            "severity": self.severity,
            "file_location": self.file_location,
            "pattern": _maybe_dict(self.pattern),
            "background": _maybe_dict(self.background),
        }

    def get_severity(self) -> str:
        """Return the severity level."""
        return self.severity or "error"


class RunOptions:  # pylint: disable=too-few-public-methods
    """RunOptions is a class to define the run options for a task"""

    def __init__(
        self,
        reevaluate_on_rerun: Optional[bool] = True,
        run_on: Optional[Literal["default", "folderOpen"]] = "default",
    ):

        self.reevaluate_on_rerun = reevaluate_on_rerun
        self.run_on = run_on


class IconOptions:  # pylint: disable=too-few-public-methods
    """IconOptions is a class to define the icon options for a task"""
    def __init__(self, icon_id: str, color: Optional[str]):
        self.id = icon_id
        self.color = color


class InputOptions:  # pylint: disable=too-few-public-methods
    """InputOptions is a class to define an input in tasks.json"""
    def __init__(  # pylint: disable=too-many-arguments, too-many-positional-arguments
        self,
        input_id: str,
        description: str,
        default: Optional[str] = None,
        input_type: Optional[Literal["promptString", "pickString"]] = "promptString",
        options: Optional[List[str]] = None,
    ):

        self.id = input_id
        self.description = description
        self.default = default
        self.type = input_type
        self.options = options


class TaskDescription:  # pylint: disable=too-few-public-methods, too-many-instance-attributes
    """TaskDescription is a class to define a task in tasks.json"""
    def __init__(  # pylint: disable=too-many-arguments, too-many-positional-arguments
        self,
        label: str,
        task_type: Literal["shell", "process"],
        command: str,
        hide: Optional[bool] = None,
        is_background: Optional[bool] = None,
        args: Optional[List[str]] = None,
        options: Optional[CommandOptions] = None,
        group: Optional[Literal["build", "test"]] = None,
        presentation: Optional[PresentationOptions] = None,
        problem_matcher: Optional[str | ProblemMatcher | List[str] | List[ProblemMatcher]] = None,
        run_options: Optional[RunOptions] = None,
        depends_order: Optional[Literal["sequence", "parallel"]] = None,
        depends_on: Optional[List[str]] = None,
        icon: Optional[IconOptions] = None,
    ):
        self.label = label
        self.task_type = task_type  # Avoid shadowing built-in 'type'
        self.command = command
        self.hide: bool = hide if hide is not None else False
        self.is_background = is_background
        self.options = options
        self.args = args
        self.group = group
        self.presentation = presentation
        self.problem_matcher = problem_matcher
        self.run_options = run_options
        self.depends_order = depends_order
        self.depends_on = depends_on
        self.icon = icon

        if options:
            self.options = _cast_from_json(options, CommandOptions)
        if presentation:
            self.presentation = _cast_from_json(presentation, PresentationOptions)
        if run_options:
            self.run_options = _cast_from_json(run_options, RunOptions)
        if icon:
            self.icon = _cast_from_json(icon, IconOptions)

    def to_dict(self):
        """Converts the task description to a dictionary."""
        return {
            "label": self.label,
            "type": self.task_type,
            "command": self.command,
            "is_background": self.is_background,
            "args": self.args,
            "options": self.options.__dict__ if self.options else None,
            "group": self.group,
            "presentation": self.presentation.__dict__ if self.presentation else None,
            "problem_matcher": self.problem_matcher,
            "run_options": self.run_options.__dict__ if self.run_options else None,
            "depends_order": self.depends_order,
            "depends_on": self.depends_on,
            "icon": self.icon.__dict__ if self.icon else None,
        }


class BaseTaskConfiguration:  # already has: pylint: disable=too-many-instance-attributes, too-few-public-methods
    """BaseTaskConfiguration is a base class to define the OS specific task configuration"""
    def __init__(  # pylint: disable=too-many-arguments, too-many-positional-arguments
        self,
        task_type: str,
        command: str,
        is_background: Optional[bool] = None,
        options: Optional[CommandOptions] = None,
        args: Optional[str] = None,
        presentation: Optional[PresentationOptions] = None,
        problem_matcher: Optional[str | ProblemMatcher | List[str] | List[ProblemMatcher]] = None,
        tasks: Optional[List[TaskDescription]] = None,
    ):
        self.task_type = task_type
        self.command = command
        self.is_background = is_background
        self.options = options
        self.args = args
        self.presentation = presentation
        self.problem_matcher = problem_matcher
        self.tasks = tasks


class TaskConfiguration:  # pylint: disable=too-few-public-methods
    """
    TorizonConfiguration is a interface to map tasks.json file
    """
    def __init__(  # pylint: disable=too-many-arguments, too-many-positional-arguments
        self,
        version: Literal["2.0.0"] = "2.0.0",
        tasks: Optional[List[TaskDescription]] = None,
        inputs: Optional[List[InputOptions]] = None,
        windows: Optional[BaseTaskConfiguration] = None,
        osx: Optional[BaseTaskConfiguration] = None,
        linux: Optional[BaseTaskConfiguration] = None,
    ):

        self.version = version
        self.tasks = tasks
        self.inputs = inputs
        self.windows = windows
        self.osx = osx
        self.linux = linux

        # as this could be from json dict, we need to cast the tasks
        if tasks:
            self.tasks = [_cast_from_json(task, TaskDescription) for task in tasks]

        if inputs:
            self.inputs = [_cast_from_json(_input, InputOptions) for _input in inputs]

        # pylint: disable-next=fixme
        # TODO:
        # for now we are not casting the other configurations
        # as them are not used in the templates


def get_tasks_json(file_path: str) -> TaskConfiguration:
    """Gets the tasks.json file for the given file path."""
    with open(f"{file_path}/.vscode/tasks.json", "r", encoding="utf-8") as file:
        return _cast_from_json(json.load(file), TaskConfiguration)


def get_settings_json(file_path: str, custom_file: str | None = None) -> TorizonSettings:
    """Gets the settings.json file for the given file path."""
    _file = custom_file if custom_file else "settings.json"
    local_settings_path = Path(file_path) / ".vscode" / _file

    try:
        with open(local_settings_path, "r", encoding="utf-8") as settings_file:
            local_settings = json.load(settings_file)
    except FileNotFoundError:
        print(f"No local settings file found at {local_settings_path}")
        local_settings = {}
    except json.JSONDecodeError as e:
        raise ValueError(f"Invalid JSON in settings file: {e}") from e

    workspace_settings = {}
    parent_dir = Path(file_path).parent
    # First check for .code-workspace files directly inside the parent
    for child in parent_dir.glob("*.code-workspace"):
        try:
            with open(child, "r", encoding="utf-8") as ws_file:
                data = json.load(ws_file)
                if "settings" in data:
                    print(f"Merging settings from: {child}")
                    workspace_settings = data["settings"]
                    break
        except (FileNotFoundError, json.JSONDecodeError) as e:
            print(f"Error reading {child}: {e}")

    # If not found, scan folders in parent_dir
    if not workspace_settings:
        for sub in parent_dir.iterdir():
            if sub.is_dir():
                for child in sub.glob("*.code-workspace"):
                    try:
                        with open(child, "r", encoding="utf-8") as ws_file:
                            data = json.load(ws_file)
                            if "settings" in data:
                                print(f"Merging settings from: {child}")
                                workspace_settings = data["settings"]
                                break
                    except (FileNotFoundError, json.JSONDecodeError) as e:
                        print(f"Error reading {child}: {e}")
                if workspace_settings:
                    break

    # Merge with local settings taking precedence
    combined = {**workspace_settings, **local_settings}
    return _cast_from_json(combined, TorizonSettings)


class TaskRunner:
    """
    TaskRunner is a class to run tasks from tasks.json file
    """

    def __init__(
        self,
        tasks: List[TaskDescription],
        inputs: List[InputOptions],
        settings: TorizonSettings,
        debug: bool = False,
    ):

        self.__tasks = tasks
        self.__inputs = inputs
        self.__settings = settings
        self.__debug = debug
        self.__gitlab_ci = False
        self.__tasks_override_env = False
        self.__cli_inputs: Dict[str, str] = {}
        # check if we have stdin
        if os.isatty(0) and (
            ("TASKS_DISABLE_INTERACTIVE_INPUT" not in os.environ)
            or (os.environ["TASKS_DISABLE_INTERACTIVE_INPUT"] != "True")
        ):
            pass

        # environment configs
        if "DOCKER_PSSWD" in os.environ:
            os.environ["config:docker_password"] = os.environ["DOCKER_PSSWD"]

        if "GITLAB_CI" in os.environ:
            self.__gitlab_ci = True

        if "TASKS_OVERRIDE_ENV" in os.environ and os.environ["TASKS_OVERRIDE_ENV"] == "True":
            self.__tasks_override_env = True

        if "TASKS_DEBUG" in os.environ and os.environ["TASKS_DEBUG"] == "True":
            self.__debug = True

        self.__settings_to_env()

    def __settings_to_env(self) -> None:
        """Export settings into env as config:<key>=<value>."""
        # Prefer public API, fall back to attrs if ever needed
        data = self.__settings.to_dict() if hasattr(
            self.__settings, "to_dict") else dict(self.__settings.__dict__
        )

        extras = data.pop("extra_settings", None)

        for key, value in data.items():
            if value is not None:
                os.environ[f"config:{key}"] = str(value)

        if isinstance(extras, dict):
            for k, v in extras.items():
                if isinstance(v, (str, int, float)):
                    os.environ[f"config:{k}"] = str(v)

    def list_labels(self, show_hidden=False, no_index: bool = False):
        """Lists the labels of all tasks."""
        i = 0

        for task in self.__tasks:
            if no_index:
                if show_hidden or not task.hide:
                    print(task.label, flush=True)
            else:
                if show_hidden or not task.hide:
                    print(f"{i}. \t{task.label}", flush=True)

            i += 1

    def desc_input(self, input_id: str):
        """Describes an input with the given id."""
        for _input in self.__inputs:
            if _input.id == input_id:
                print(json.dumps(_input.__dict__, indent=4))
                return

        raise ReferenceError(f"Input with id [{input_id}] not found")

    def desc_task(self, label: int | str):
        """Describes a task with the given label."""
        task = None

        if isinstance(label, int):
            task = self.__tasks[label]
        else:
            for _task in self.__tasks:
                if _task.label == label:
                    task = _task
                    break

        if task is not None:
            task_txt = json.dumps(task.to_dict(), indent=4)
            print(task_txt, flush=True)
        else:
            raise ReferenceError(f"Task with index [{label}] not found")

    def __replace_env_var(self, var: str, env: str) -> str:
        token = f"${{{var}}}"
        if token in env and var in os.environ:
            return env.replace(token, os.environ[var])
        return env

    def __check_workspace_folder(self, env: List[str]) -> List[str]:
        ret: List[str] = []

        for value in env:
            if "workspaceFolderBasename" in value:
                value = self.__replace_env_var("workspaceFolderBasename", value)
            if "workspaceFolder" in value:
                value = self.__replace_env_var("workspaceFolder", value)
            ret.append(value)

        return ret

    def __check_torizon_inputs(self, env: List[str]) -> List[str]:
        ret: List[str] = []

        for value in env:
            if "${command:torizon_" in value:
                value = value.replace("${command:torizon_", "${config:torizon_")
            ret.append(value)

        return ret

    def __check_docker_inputs(self, env: List[str]) -> List[str]:
        ret: List[str] = []

        for value in env:
            if "${command:docker_" in value:
                value = value.replace("${command:docker_", "${config:docker_")
            ret.append(value)

        return ret

    def __check_tcb_inputs(self, env: List[str]) -> List[str]:  # pylint: disable=too-many-locals
        ret: List[str] = []

        for value in env:
            if "${command:tcb" in value:
                if "tcb.getNextPackageVersion" in value:
                    # call the xonsh script
                    _p_ret = subprocess.run(
                        [
                            "xonsh",
                            "./.conf/torizon-io.xsh",
                            "package",
                            "latest",
                            "version",
                            os.environ["config:tcb_package_name"],
                        ],
                        capture_output=True,
                        text=True,
                        env=os.environ,
                        check=False,
                    )

                    if _p_ret.returncode != 0:
                        # Sometimes the error is presented on stdout and not stderr
                        raise RuntimeError(f"Error running torizon-io.xsh: {_p_ret}")

                    # Remove ANSI escape sequences.
                    ansi_escape = re.compile(r"\x1B(?:[@-Z\\-_]|\[[0-?]*[ -/]*[@-~])")
                    _latest_ver = ansi_escape.sub("", _p_ret.stdout.strip())

                    # Extract the last number from the version string
                    _latest_ver_last_number = _latest_ver.split(".")[-1]
                    try:
                        _next = int(_latest_ver_last_number) + 1
                    except ValueError as exc:
                        raise ValueError(
                            "Invalid package version format. Expected <int>, <str-int>, "
                            "<major.minor.patch>, or <str-major.minor.patch>."
                        ) from exc

                    if self.__debug:
                        print(f"Next package version: {_next}", flush=True)

                    value = value.replace("${command:tcb.getNextPackageVersion}", str(_next))

                elif "tcb.outputTEZIFolder" in value:
                    # load the tcbuild.yaml
                    with open("tcbuild.yaml", "r", encoding="utf-8") as file:
                        _tcbuild = yaml.load(file, Loader=yaml.FullLoader)

                        try:
                            _tezi_folder = _tcbuild["output"]["easy-installer"]["local"]
                        except KeyError as exc:
                            raise RuntimeError(
                                "Error replacing variable tcb.outputTEZIFolder, "
                                #pylint: disable=line-too-long
                                "make sure the tcbuild.yaml has the output.easy-installer.local property"
                            ) from exc

                        value = value.replace("${command:tcb.outputTEZIFolder}", _tezi_folder)

                # for all the items we need to replace ${command:tcb. with ${config:tcb.
                _pattern = r"(?<=\$\{command:tcb\.).*?(?=\s*})"
                _matches = re.findall(_pattern, value)

                for match in _matches:
                    value = value.replace(f"${{command:tcb.{match}}}", f"${{config:tcb.{match}}}")

            ret.append(value)

        return ret

    def __check_vscode_env(self, args: List[str]) -> List[str]:
        """
        handle the VS Code ${env:VAR} replacement
        """
        ret: List[str] = []

        for arg in args:
            if "${env:" in arg:
                _pattern = r"(?<=\$\{env:).*?(?=\s*})"
                _matches = re.findall(_pattern, arg)

                for match in _matches:
                    if match not in os.environ:
                        raise ReferenceError(f"Environment variable with id [{match}] not found")

                    arg = arg.replace(f"${{env:{match}}}", os.environ[match])

            ret.append(arg)

        return ret

    def __parse_envs(self, env: str, task: TaskDescription) -> str | None:
        """
        It's christmas time 🎅
        """
        _env_value: Optional[str] = None

        if task.options:
            value = task.options.env or {}

            # get the env from the task
            _env_value = value.get(env)

        if _env_value:
            expvalue = [_env_value]
            expvalue = self.__check_workspace_folder(expvalue)
            expvalue = self.__check_torizon_inputs(expvalue)
            expvalue = self.__check_docker_inputs(expvalue)
            expvalue = self.__check_tcb_inputs(expvalue)
            expvalue = self.__check_config(expvalue)
            exp_value_str = " ".join(expvalue)
            if self.__debug:
                print(f"Env: {env}={_env_value}", color=Color.YELLOW, flush=True)
                print(
                    f"Parsed Env: {env}={exp_value_str}",
                    color=Color.YELLOW,
                    flush=True,
                )

            return exp_value_str

        return None

    def __replace_docker_host(self, arg: str) -> str:
        if "DOCKER_HOST" in arg and is_in_docker_container():
            arg = arg.replace("DOCKER_HOST=", "DOCKER_HOST=tcp://docker:2375")

        return arg

    def set_cli_inputs(self, cli_inputs: Dict[str, str]) -> None:
        """
        Set the cli inputs to be used in the tasks.
        """
        for key, value in cli_inputs.items():
            # validate if the key is in the inputs
            _input = None
            _input = next((inp for inp in self.__inputs if inp.id == key), None)

            if _input is None:
                raise ReferenceError(f"Input with id [{key}] not found")

            self.__cli_inputs[key] = value

    def run_task(self, label: str) -> None:  # pylint: disable=too-many-locals, too-many-branches, too-many-statements
        """Runs a task with the given label."""
        # query the task
        _task = None
        _task = next((task for task in self.__tasks if task.label == label), None)

        if _task is None:
            raise ReferenceError(f"Task with label [{label}] not found")

        _depends = []
        if _task.depends_on is not None:
            _depends = _task.depends_on

        # first we need to run the dependencies
        for dep in _depends:
            self.run_task(dep)

        print(f"> Executing task: {label} <", color=Color.GREEN, flush=True)

        # prepare the command
        _cmd = _task.command

        # the cmd itself can use the mechanism to replace stuff
        _cmd = self.__check_workspace_folder([_cmd])[0]
        _cmd = self.__check_torizon_inputs([_cmd])[0]
        _cmd = self.__check_docker_inputs([_cmd])[0]
        _cmd = self.__check_tcb_inputs([_cmd])[0]
        _cmd = self.__check_vscode_env([_cmd])[0]
        _cmd = self.__check_config([_cmd])[0]

        _args: List[str] = []
        if _task.args is not None:
            _args = _task.args

        _env: Dict[str, str] | None = {}
        _cwd = None
        _last_cwd = os.getcwd()
        if _task.options is not None:
            _env = _task.options.env
            _cwd = _task.options.cwd

        _is_background = ""
        if _task.is_background:
            _is_background = " &"

        _shell = _task.task_type == "shell"

        # pylint: disable-next=fixme
        # FIXME:    The scape args was in the powershell implementation
        #           but when used on Python it generates weird behavior
        _args = self.__check_workspace_folder(_args)
        _args = self.__check_torizon_inputs(_args)
        _args = self.__check_docker_inputs(_args)
        _args = self.__check_tcb_inputs(_args)
        _args = self.__check_vscode_env(_args)
        _args = self.__check_config(_args)
        _args = self.__check_workspace_folder(_args)
        # pylint: disable-next=fixme
        # FIXME:    These was in the powershell implementation
        #           but when used on Python it generates weird behavior
        # _args = self.__check_long_args(_args)

        # if in gitlab ci env we need to replace the DOCKER_HOST
        if self.__gitlab_ci:
            _cmd = self.__replace_docker_host(_cmd)

        task_env = os.environ.copy()
        # If TASKS_OVERRIDE_ENV is true, override the env vars with the
        # env var values present on the task. If false, set just the env vars
        # present on the task that doesn't already exist on the env var
        if _env is not None:
            for env, _ in _env.items():
                if self.__tasks_override_env or env not in os.environ:
                    __parsed_env_value = self.__parse_envs(env, _task)
                    task_env[env] = __parsed_env_value

        # we need to change the cwd if it's set
        if _cwd is not None:
            _cwd = self.__check_workspace_folder([_cwd])[0]
            _cwd = self.__check_config([_cwd])[0]
            _cwd = self.__check_vscode_env([_cwd])[0]

            os.chdir(_cwd)

        # execute the task
        _cmd_join = f"{_cmd} {' '.join(_args)}{_is_background}"

        if self.__debug:
            print(f"Command: {_task.command}", color=Color.YELLOW, flush=True)
            print(f"Args: {_task.args}", color=Color.YELLOW, flush=True)
            print(f"Parsed Args: {_args}", color=Color.YELLOW, flush=True)
            print(f"Parsed Command: {_cmd_join}", color=Color.YELLOW, flush=True)

        # use bash to execute the VSCode tasks commands and scripts, as they
        # are written and tested in bash. Valid just for commands of shell
        # type, not process type ones
        _ret = subprocess.run(
            [_cmd, *_args] if not _shell else _cmd_join,
            stdout=None,
            stderr=None,
            env=task_env,
            shell=_shell,
            executable="/bin/bash" if _shell else None,
            check=False,
        )

        # go back to the last cwd
        os.chdir(_last_cwd)

        if _ret.returncode != 0:
            print(
                f"> TASK [{label}] exited with error code [{_ret.returncode}] <",
                color=Color.RED,
                flush=True,
            )
            raise RuntimeError(f"Error running task: {label}")

    def __check_config(self, args: List[str]) -> List[str]:
        """Replace VS Code-style ${config:...} tokens with setting-derived env values."""
        ret: List[str] = []
        pattern = re.compile(r"\$\{config:([^}]+)\}")

        for arg in args:

            def _sub(match: re.Match[str]) -> str:
                key = match.group(1)
                full = f"config:{key}"
                if full not in os.environ:
                    raise ReferenceError(f"Config variable with id [{key}] not found")
                return os.environ[full]

            ret.append(pattern.sub(_sub, arg))
        return ret

