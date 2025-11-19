
import os
import re
import yaml # type: ignore[import-untyped]
import json
import inspect
import mimetypes
import subprocess
from pathlib import Path
from typing import List, Dict, Type, TypeVar, Union, Tuple, Optional, Literal
from torizon_templates_utils.network import is_in_docker_container
from torizon_templates_utils.colors import print, Color

T = TypeVar('T')

REPLACE_WHITELIST = [
    "torizon_",
    "docker_",
    "inputBox-"
]

def replace_tasks_input():
    for file in Path('.').rglob('*.json'):
        print(file, flush=True)
        mime_type, _ = mimetypes.guess_type(file)

        if mime_type is None or mime_type.startswith("application/octet-stream"):
            if "id_rsa" not in str(file):
                with open(file, 'r') as f:
                    content = f.read()

                content = content.replace("input:dockerLogin", "command:docker_login.__change__")
                content = content.replace("input:dockerImageRegistry", "command:inputBox-docker_registry.__change__")
                content = content.replace("input:dockerPsswd", "command:docker_password.__change__")

                with open(file, 'w') as f:
                    f.write(content)


def _cast_from_json(json_data, cls: Type[T]) -> T:
    # check on json_data if there is some key with . like "name.prop"
    # if so, we need change the key to something like "name_prop"
    keys = list(json_data.keys())
    for key in keys:
        if '.' in key:
            new_key = key.replace('.', '_')
            json_data[new_key] = json_data.pop(key)

    expected_args = inspect.signature(cls.__init__).parameters
    filtered_data = {k: v for k, v in json_data.items() if k in expected_args}

    # check if the cls type has the any attribute
    # the any attribute is a Dict[str, str]
    # and it store the non expected args
    if 'any' in expected_args:
        non_expected_args = {k: v for k, v in json_data.items() if k not in expected_args}
        filtered_data['any'] = non_expected_args

    return cls(**filtered_data)


# For Settings interface we are mapping only the Torizon specific settings
class TorizonSettings:
    """
    TorizonSettings is a interface to map specific VS Code settings defined
    by the Torizon extension.
    """
    def __init__(
            self,
            torizon_psswd: Optional[str] = None,
            torizon_login: Optional[str] = None,
            torizon_ip: Optional[str] = None,
            torizon_ssh_port: Optional[str] = None,
            host_ip: Optional[str] = None,
            torizon_workspace: Optional[str] = None,
            torizon_debug_ssh_port: Optional[str] = None,
            torizon_debug_port1: Optional[str] = None,
            torizon_debug_port2: Optional[str] = None,
            torizon_debug_port3: Optional[str] = None,
            torizon_gpu: Optional[str] = None,
            torizon_arch: Optional[str] = None,
            wait_sync: Optional[str] = None,
            torizon_run_as: Optional[str] = None,
            torizon_app_root: Optional[str] = None,
            docker_tag: Optional[str] = None,
            tcb_packageName: Optional[str] = None,
            tcb_version: Optional[str] = None,
            torizon_gpuPrefixRC: Optional[str] = None,
            any: Optional[Dict[str, str]] = None
        ):

        self.torizon_psswd = torizon_psswd
        self.torizon_login = torizon_login
        self.torizon_ip = torizon_ip
        self.torizon_ssh_port = torizon_ssh_port
        self.host_ip = host_ip
        self.torizon_workspace = torizon_workspace
        self.torizon_debug_ssh_port = torizon_debug_ssh_port
        self.torizon_debug_port1 = torizon_debug_port1
        self.torizon_debug_port2 = torizon_debug_port2
        self.torizon_debug_port3 = torizon_debug_port3
        self.torizon_gpu = torizon_gpu
        self.torizon_arch = torizon_arch
        self.wait_sync = wait_sync
        self.torizon_run_as = torizon_run_as
        self.torizon_app_root = torizon_app_root
        self.docker_tag = docker_tag
        self.tcb_packageName = tcb_packageName
        self.tcb_version = tcb_version
        self.torizon_gpuPrefixRC = torizon_gpuPrefixRC
        self.any = any


# These are from:
# https://code.visualstudio.com/docs/editor/tasks-appendix

class ShellConfiguration:
    def __init__(self, executable: str, args: Optional[List[str]]):
        self.executable = executable
        self.args = args

class CommandOptions:
    def __init__(
            self,
            cwd: Optional[str] = None,
            env: Optional[Dict[str, str]] = None,
            shell: Optional[ShellConfiguration] = None
        ):

        self.cwd = cwd
        self.env = env
        self.shell = shell

        # we are getting this data from json
        # so we need to cast the classes dependencies
        if shell:
            self.shell = _cast_from_json(shell, ShellConfiguration)


class PresentationOptions:
    def __init__(
            self,
            reveal: Optional[Literal['never', 'silent', 'always']] = None,
            echo: Optional[bool] = None,
            focus: Optional[bool] = None,
            panel: Optional[Literal['shared', 'dedicated', 'new']] = None,
            showReuseMessage: Optional[bool] = None,
            clear: Optional[bool] = None,
            group: Optional[str] = None
        ):

        self.reveal = reveal
        self.echo = echo
        self.focus = focus
        self.panel = panel
        self.showReuseMessage = showReuseMessage
        self.clear = clear
        self.group = group


class ProblemPattern:
    def __init__(
            self,
            regexp: str,
            kind: Optional[Literal['file', 'location']] = None,
            file: Union[int, float] = 0,
            location: Optional[Union[int, float]] = None,
            line: Optional[Union[int, float]] =None,
            column: Optional[Union[int, float]] = None,
            endLine: Optional[Union[int, float]] = None,
            endColumn: Optional[Union[int, float]] = None,
            severity: Optional[Union[int, float]] = None,
            code: Optional[Union[int, float]] = None,
            message: Union[int, float] = 0,
            loop: Optional[bool] = False
        ):

        self.regexp = regexp
        self.kind = kind
        self.file = file
        self.location = location
        self.line = line
        self.column = column
        self.endLine = endLine
        self.endColumn = endColumn
        self.severity = severity
        self.code = code
        self.message = message
        self.loop = loop


class BackgroundMatcher:
    def __init__(
            self,
            activeOnStart: Optional[bool] = False,
            beginsPattern: Optional[str] = None,
            endsPattern: Optional[str] = None
        ):

        self.activeOnStart = activeOnStart
        self.beginsPattern = beginsPattern
        self.endsPattern = endsPattern


class ProblemMatcher:
    def __init__(
            self,
            base: Optional[str] = None,
            owner: Optional[str] = 'external',
            source: Optional[str] = None,
            severity: Optional[Literal['error', 'warning', 'info']] = 'error',
            fileLocation: Optional[str | List[str] | List[
                Union[
                    Literal['search'],
                    Dict[str, Optional[List[str]]]
                ]
            ]] = None,
            pattern: Optional[str | ProblemPattern | List[ProblemPattern]] = None,
            background: Optional[BackgroundMatcher] = None
        ):

        self.base = base
        self.owner = owner
        self.source = source
        self.severity = severity
        self.fileLocation = fileLocation
        self.pattern = pattern
        self.background = background

        # we are getting this data from json
        # so we need to cast the classes dependencies
        if pattern:
            self.pattern = _cast_from_json(pattern, ProblemPattern)

        if background:
            self.background = _cast_from_json(background, BackgroundMatcher)


class RunOptions:
    def __init__(
            self,
            reevaluateOnRerun: Optional[bool] = True,
            runOn: Optional[Literal['default', 'folderOpen']] = 'default'
        ):

        self.reevaluateOnRerun = reevaluateOnRerun
        self.runOn = runOn


class IconOptions:
    def __init__(
            self,
            id: str,
            color: Optional[str]
        ):

        self.id = id
        self.color = color


class InputOptions:
    def __init__(
            self,
            id: str,
            description: str,
            default: Optional[str] = None,
            type: Optional[Literal['promptString', 'pickString']] = 'promptString',
            options: Optional[List[str]] = None
        ):

        self.id = id
        self.description = description
        self.default = default
        self.type = type
        self.options = options


class TaskDescription:
    def __init__(
            self,
            label: str,
            type: Literal['shell', 'process'],
            command: str,
            hide: Optional[bool] = None,
            isBackground: Optional[bool] = None,
            args: Optional[List[str]] = None,
            options: Optional[CommandOptions] = None,
            group: Optional[Literal['build', 'test']] = None,
            presentation: Optional[PresentationOptions] = None,
            problemMatcher: Optional[str | ProblemMatcher | List[str] | List[ProblemMatcher]] = None,
            runOptions: Optional[RunOptions] = None,
            dependsOrder: Optional[Literal['sequence', 'parallel']] = None,
            dependsOn: Optional[List[str]] = None,
            icon: Optional[IconOptions] = None
        ):

        self.label = label
        self.type = type
        self.command = command
        self.hide: bool = (hide if hide is not None else False)
        self.isBackground = isBackground
        self.options = options
        self.args = args
        self.group = group
        self.presentation = presentation
        self.problemMatcher = problemMatcher
        self.runOptions = runOptions
        self.dependsOrder = dependsOrder
        self.dependsOn = dependsOn
        self.icon = icon

        # we are getting this data from json
        # so we need to cast the classes dependencies
        if options:
            self.options = _cast_from_json(options, CommandOptions)

        if presentation:
            self.presentation = _cast_from_json(presentation, PresentationOptions)

        if runOptions:
            self.runOptions = _cast_from_json(runOptions, RunOptions)

        if icon:
            self.icon = _cast_from_json(icon, IconOptions)

    def to_dict(self):
        return {
            'label': self.label,
            'type': self.type,
            'command': self.command,
            'isBackground': self.isBackground,
            'args': self.args,
            'options': self.options.__dict__ if self.options else None,
            'group': self.group,
            'presentation': self.presentation.__dict__ if self.presentation else None,
            'problemMatcher': self.problemMatcher,
            'runOptions': self.runOptions.__dict__ if self.runOptions else None,
            'dependsOrder': self.dependsOrder,
            'dependsOn': self.dependsOn,
            'icon': self.icon.__dict__ if self.icon else None
        }


class BaseTaskConfiguration:
    def __init__(
            self,
            type: str,
            command: str,
            isBackground: Optional[bool] = None,
            options: Optional[CommandOptions] = None,
            args: Optional[str] = None,
            presentation: Optional[PresentationOptions] = None,
            problemMatcher: Optional[str | ProblemMatcher | List[str] | List[ProblemMatcher]] = None,
            tasks: Optional[List[TaskDescription]] = None
        ):

        self.type = type
        self.command = command
        self.isBackground = isBackground
        self.options = options
        self.args = args
        self.presentation = presentation
        self.problemMatcher = problemMatcher
        self.tasks = tasks


class TaskConfiguration:
    """
    TorizonConfiguration is a interface to map tasks.json file
    """

    def __init__(
            self,
            version: Literal['2.0.0'] = '2.0.0',
            tasks: Optional[List[TaskDescription]] = None,
            inputs: Optional[List[InputOptions]] = None,
            windows: Optional[BaseTaskConfiguration] = None,
            osx: Optional[BaseTaskConfiguration] = None,
            linux: Optional[BaseTaskConfiguration] = None
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

        # TODO:
        # for now we are not casting the other configurations
        # as them are not used in the templates


def get_tasks_json(file_path: str) -> TaskConfiguration:
    with open(f"{file_path}/.vscode/tasks.json", 'r') as file:
        return _cast_from_json(json.load(file), TaskConfiguration)


def get_settings_json(
    file_path: str,
    custom_file: str | None = None
) -> TorizonSettings:
    _file = custom_file if custom_file else "settings.json"
    local_settings_path = Path(file_path) / ".vscode" / _file

    try:
        with open(local_settings_path, 'r') as file:
            local_settings = json.load(file)
    except FileNotFoundError:
        print(f"No local settings file found at {local_settings_path}")
        local_settings = {}
    except json.JSONDecodeError as e:
        raise ValueError(f"Invalid JSON in settings file: {e}")

    workspace_settings = {}
    parent_dir = Path(file_path).parent
    # First check for .code-workspace files directly inside the parent
    for child in parent_dir.glob("*.code-workspace"):
        try:
            with open(child, "r") as ws_file:
                data = json.load(ws_file)
                if "settings" in data:
                    print(f"Merging settings from: {child}")
                    workspace_settings = data["settings"]
                    break
        except Exception as e:
            print(f"Error reading {child}: {e}")

    # If not found, scan folders in parent_dir
    if not workspace_settings:
        for sub in parent_dir.iterdir():
            if sub.is_dir():
                for child in sub.glob("*.code-workspace"):
                    try:
                        with open(child, "r") as ws_file:
                            data = json.load(ws_file)
                            if "settings" in data:
                                print(f"Merging settings from: {child}")
                                workspace_settings = data["settings"]
                                break
                    except Exception as e:
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
            debug: bool = False
        ):

        self.__tasks = tasks
        self.__inputs = inputs
        self.__settings = settings
        self.__debug = debug
        self.__gitlab_ci = False
        self.__tasks_override_env = False
        self.__cli_inputs: Dict[str, str] = {}
        self.__can_receive_interactive_input = False

        # check if we have stdin
        if os.isatty(0) and (("TASKS_DISABLE_INTERACTIVE_INPUT" not in os.environ) or (os.environ["TASKS_DISABLE_INTERACTIVE_INPUT"] != "True")):
            self.__can_receive_interactive_input = True

        # environment configs
        if "DOCKER_PASSWORD" in os.environ:
            os.environ["config:docker_password"] = os.environ["DOCKER_PASSWORD"]

        if "GITLAB_CI" in os.environ:
            self.__gitlab_ci = True

        if "TASKS_OVERRIDE_ENV" in os.environ and os.environ["TASKS_OVERRIDE_ENV"] == "True":
            self.__tasks_override_env = True

        if "TASKS_DEBUG" in os.environ and os.environ["TASKS_DEBUG"] == "True":
            self.__debug = True

        self.__settings_to_env()


    def __settings_to_env(self):
        # for keys in settings, we are adding to env
        for key, value in self.__settings.__dict__.items():
            if value is not None:
                os.environ[f"config:{key}"] = f"{value}"

        # also for non Torizon ones
        for key, value in self.__settings.any.items():
            if isinstance(value, str) or \
                isinstance(value, int) or \
                isinstance(value, float):

                os.environ[f"config:{key}"] = str(value)


    def list_labels(self, show_hidden=False, no_index: bool = False):
        i = 0

        for task in self.__tasks:
            if no_index:
                if show_hidden or not task.hide:
                    print(task.label, flush=True)
            else:
                if show_hidden or not task.hide:
                    print(f"{i}. \t{task.label}", flush=True)

            i += 1


    def desc_input(self, id: str):
        for _input in self.__inputs:
            if _input.id == id:
                print(json.dumps(_input.__dict__, indent=4))
                return

        raise ReferenceError(f"Input with id [{id}] not found")


    def desc_task(self, label: int | str):
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


    def __replace_env_var(self, var: str, env: str):
        if f"${{{var}}}" in env:
            return env.replace(f"${{{var}}}", os.environ[var])


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
                # here is not needed to clean the torizon_<prop>.<project_name>
                # because this will be handled on the cmd args check
                value = value.replace("${command:torizon_", "${config:torizon_")

            ret.append(value)

        return ret


    def __check_input_boxes(self, env: List[str]) -> List[str]:
        ret: List[str] = []

        for value in env:
            value = value.replace("${command:inputBox-", "${config:")
            ret.append(value)

        return ret


    def __check_cmd_args(self, env: List[str]) -> List[str]:
        ret: List[str] = []

        for value in env:
            for whitelisted_start in REPLACE_WHITELIST:
                if value.startswith("${command:" + whitelisted_start) or value.startswith("${config:" + whitelisted_start):

                    if "." in value:
                        value_p1, value_p2 = value.split(".", 1)
                        ret_p2 = value_p2.split("}", 1)

                        if len(ret_p2) > 1:
                            value = f"{value_p1}}}{ret_p2[1]}"
                        else:
                            value = f"{value_p1}}}"
                    break

            ret.append(value)

        return ret


    def __check_docker_inputs(self, env: List[str]) -> List[str]:
        ret: List[str] = []

        for value in env:
            if "${command:docker_" in value:
                value = value.replace("${command:docker_", "${config:docker_")
            ret.append(value)

        return ret


    def __check_tcb_inputs(self, env: List[str]) -> List[str]:
        ret: List[str] = []

        for value in env:
            if "${command:tcb" in value:
                if "tcb.getNextPackageVersion" in value:
                    # call the xonsh script
                    _p_ret = subprocess.run(
                        [
                            "xonsh",
                            "./.conf/torizon-io.xsh",
                            "package", "latest", "version",
                            os.environ["config:tcb_packageName"]
                        ],
                        capture_output=True,
                        text=True,
                        env=os.environ
                    )

                    if _p_ret.returncode != 0:
                        # Sometimes the error is presented on stdout and not stderr
                        raise RuntimeError(f"Error running torizon-io.xsh: {_p_ret}")

                    # TODO: Maybe not use this and instead disable colors on the terminal
                    # Remove ANSI escape sequences. Regex from this thread:
                    # https://stackoverflow.com/questions/14693701/how-can-i-remove-the-ansi-escape-sequences-from-a-string-in-python
                    ansi_escape = re.compile(r'\x1B(?:[@-Z\\-_]|\[[0-?]*[ -/]*[@-~])')
                    _latest_ver = ansi_escape.sub('', _p_ret.stdout.strip())

                    _latest_ver_number = _latest_ver.rsplit('-', 1)[-1]
                    _latest_ver_last_number = _latest_ver_number.rsplit('.', 1)[-1]
                    try:
                        _next = int(_latest_ver_last_number) +1
                    except:
                        raise ValueError(f"Package version should be in one of the following formats: <int>, <string-int>, <major.minor.patch>, or <string-major.minor.patch>. Depending on format, int or patch value will be incremented")

                    if self.__debug:
                        print(f"Next package version: {_next}", flush=True)

                    value = value.replace(f"${{command:tcb.getNextPackageVersion}}", f"{_next}")

                elif "tcb.outputTEZIFolder" in value:
                    # load the tcbuild.yaml
                    with open("tcbuild.yaml", 'r') as file:
                        _tcbuild = yaml.load(file, Loader=yaml.FullLoader)

                        _tezi_folder = None
                        try:
                            _tezi_folder = _tcbuild["output"]["easy-installer"]["local"]
                        except KeyError:
                            raise RuntimeError("Error replacing variable tcb.outputTEZIFolder, make sure the tcbuild.yaml has the output.easy-installer.local property")

                        value = value.replace(f"${{command:tcb.outputTEZIFolder}}", _tezi_folder)

                # for all the items we need to replace ${command:tcb. with ${config:tcb.
                _pattern = r"(?<=\$\{command:tcb\.).*?(?=\s*})"
                _matches = re.findall(_pattern, value)

                for match in _matches:
                    value = value.replace(f"${{command:tcb.{match}}}", f"${{config:tcb.{match}}}")

            ret.append(value)

        return ret


    def __contains_special_chars(self, str: str) -> bool:
        _pattern = r"[^a-zA-Z0-9\.\-_|>\/=+&_]"
        return re.search(_pattern, str) is not None


    def __scape_args(self, args: List[str]) -> List[str]:
        ret: List[str] = []

        for arg in args:
            if "\"" in arg:
                arg = arg.replace("\"", "\\\"")

            ret.append(arg)

        return ret


    def __check_config(self, args: List[str]) -> List[str]:
        """
        This method will make the config replacement in the args
        """
        ret: List[str] = []

        for arg in args:
            if "${config:" in arg:
                _pattern = r"(?<=\$\{config:).*?(?=\s*})"
                _matches = re.findall(_pattern, arg)

                for match in _matches:
                    if "." in match:
                        _match = match.replace(".", "_")
                    else:
                        _match = match

                    # first check if the config exists
                    if f"config:{_match}" not in os.environ:
                        raise ReferenceError(f"Config with id [{match}] not found. Check your settings.json")

                    # edge case for docker_registry
                    if _match == "docker_registry" and os.environ[f"config:{_match}"] == "":
                        os.environ[f"config:{_match}"] = "registry-1.docker.io"

                    arg = arg.replace(f"${{config:{match}}}", os.environ[f"config:{_match}"])

            ret.append(arg)

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


    def __check_long_args(self, args: List[str]) -> List[str]:
        ret: List[str] = []

        for arg in args:
            if " " in arg:
                arg = f"'{arg}'"

            ret.append(arg)

        return ret


    def __quoting_special_chars(self, args: List[str]) -> List[str]:
        ret: List[str] = []

        for arg in args:
            _has_special_chars = self.__contains_special_chars(arg)
            _hash_space = " " in arg

            if _has_special_chars and not _hash_space:
                arg = f"'{arg}'"

            ret.append(arg)

        return ret


    def __check_input(self, args: List[str]) -> List[str]:
        ret: List[str] = []

        for arg in args:
            if "${input:" in arg:
                _pattern = r"(?<=\$\{input:).*?(?=\s*})"
                _matches = re.findall(_pattern, arg)

                for match in _matches:
                    _input = None
                    _input_value = "None"

                    for inp in self.__inputs:
                        if inp.id == match:
                            _input = inp
                            break

                    if _input is None:
                        raise ReferenceError(f"Input with id [{match}] not found")

                    # first check if the input was set by cli
                    if match in self.__cli_inputs:
                        _input_value = self.__cli_inputs[match]
                    elif _input.default:
                        _input_value = _input.default
                    else:
                        if not self.__can_receive_interactive_input:
                            raise RuntimeError("CLI inputs not set and interactive input is disabled")

                        if _input.type == "promptString":
                            _input_value = input(f"{_input.description}: ")
                        elif _input.type == "pickString":
                            for _inp in self.__inputs:
                                if _inp.id == match:
                                    # print options
                                    assert _inp.options is not None, "pickString option has a valid id but options is empty. Check your tasks.json"
                                    print(f"Options for [{match}]:")
                                    _i = 0
                                    _indexed_options = {}

                                    for _opt in _inp.options:
                                        _indexed_options[str(_i)] = _opt
                                        print(f"{_i}. {_opt}")
                                        _i += 1

                                    _input_value = input(f"{_input.description} (option index): ")

                                    # check if the input is in the options
                                    if _input_value not in _indexed_options:
                                        raise ValueError(f"Input value for [{match}] is not in the possible options")
                                    else:
                                        _input_value = _indexed_options[_input_value]

                        if _input_value is None:
                            raise ValueError(f"Input value for [{match}] could not be None")

                    arg = arg.replace(f"${{input:{match}}}", _input_value)

            ret.append(arg)

        return ret


    def __parse_envs(self, env: str, task: TaskDescription) -> str | None :
        """
        It's christmas time 🎅
        """
        if task.options:
            value = task.options.env

            # get the env from the task
            if value:
                _env_value = value.get(env)

            if _env_value:
                expvalue = [_env_value]
                expvalue = self.__check_cmd_args(expvalue)
                expvalue = self.__check_workspace_folder(expvalue)
                expvalue = self.__check_input_boxes(expvalue)
                expvalue = self.__check_torizon_inputs(expvalue)
                expvalue = self.__check_docker_inputs(expvalue)
                expvalue = self.__check_tcb_inputs(expvalue)
                expvalue = self.__check_input(expvalue)
                expvalue = self.__check_config(expvalue)
                exp_value_str = " ".join(expvalue)

                if self.__debug:
                    print(f"Env: {env}={_env_value}", color=Color.YELLOW, flush=True)
                    print(f"Parsed Env: {env}={exp_value_str}", color=Color.YELLOW, flush=True)

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


    def run_task(self, label: str) -> None:
        # query the task
        _task = None
        _task = next((task for task in self.__tasks if task.label == label), None)

        if _task is None:
            raise ReferenceError(f"Task with label [{label}] not found")

        _depends = []
        if _task.dependsOn is not None:
            _depends = _task.dependsOn

        # first we need to run the dependencies
        for dep in _depends:
            self.run_task(dep)

        print(f"> Executing task: {label} <", color=Color.GREEN, flush=True)

        # prepare the command
        _cmd = _task.command

        # the cmd itself can use the mechanism to replace stuff
        _cmd = self.__check_cmd_args([_cmd])[0]
        _cmd = self.__check_workspace_folder([_cmd])[0]
        _cmd = self.__check_input_boxes([_cmd])[0]
        _cmd = self.__check_torizon_inputs([_cmd])[0]
        _cmd = self.__check_docker_inputs([_cmd])[0]
        _cmd = self.__check_tcb_inputs([_cmd])[0]
        _cmd = self.__check_input([_cmd])[0]
        _cmd = self.__check_vscode_env([_cmd])[0]
        _cmd = self.__check_config([_cmd])[0]

        _args = []
        if _task.args is not None:
            _args = _task.args

        _env: Dict[str, str] | None = {}
        _cwd = None
        _last_cwd = os.getcwd()
        if _task.options is not None:
            _env = _task.options.env
            _cwd = _task.options.cwd

        _is_background = ""
        if _task.isBackground:
            _is_background = " &"

        _shell = _task.type == "shell"

        # FIXME:    The scape args was in the powershell implementation
        #           but when used on Python it generates weird behavior
        # _args = self.__scape_args(_args)
        _args = self.__check_cmd_args(_args)
        _args = self.__check_workspace_folder(_args)
        _args = self.__check_input_boxes(_args)
        _args = self.__check_torizon_inputs(_args)
        _args = self.__check_docker_inputs(_args)
        _args = self.__check_tcb_inputs(_args)
        _args = self.__check_input(_args)
        _args = self.__check_vscode_env(_args)
        _args = self.__check_config(_args)
        _args = self.__check_workspace_folder(_args)

        if _shell:
            _args = self.__check_long_args(_args)

        # FIXME:    These was in the powershell implementation
        #           but when used on Python it generates weird behavior
        # _args = self.__quoting_special_chars(_args)

        # if in gitlab ci env we need to replace the DOCKER_HOST
        if self.__gitlab_ci:
            _cmd = self.__replace_docker_host(_cmd)

        task_env = os.environ.copy()
        # If TASKS_OVERRIDE_ENV is true, override the env vars with the
        # env var values present on the task. If false, set just the env vars
        # present on the task that doesn't already exist on the env var
        if _env is not None:
            for env, _ in _env.items():
                if self.__tasks_override_env == True or env not in os.environ:
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
            executable="/bin/bash" if _shell else None
        )

        # go back to the last cwd
        os.chdir(_last_cwd)

        if _ret.returncode != 0:
            print(f"> TASK [{label}] exited with error code [{_ret.returncode}] <", color=Color.RED, flush=True)
            raise RuntimeError(f"Error running task: {label}")
