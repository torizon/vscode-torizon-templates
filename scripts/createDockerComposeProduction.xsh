#!/usr/bin/env xonsh

import os
import sys
import yaml

RED = "\x1b[31m"
GREEN = "\x1b[32m"
YELLOW = "\x1b[33m"
RESET = "\x1b[0m"

$ErrorActionPreference = "Stop"
$PSNativeCommandUseErrorActionPreference = True

$DOCKER_HOST = ""

if "GITLAB_CI" in $ENV and $GITLAB_CI == "true":
    print("ℹ️ :: GITLAB_CI :: ℹ️")
    $DOCKER_HOST = "tcp://docker:2375"

args = $ARGS
if len(args) < 5:
    print(f"{RED}❌ Not enough arguments provided{RESET}")
    print("usage: build_and_push.xsh <compoFilePath> <dockerLogin> <tag> <registry> <imageName> [gpu]")
    sys.exit(1)

compoFilePath = args[0]
dockerLogin = args[1]
tag = args[2]
registry = args[3]
imageName = args[4]
gpu = args[5] if len(args) > 5 else None

_iterative = True
if "TASKS_ITERATIVE" in $ENV and $TASKS_ITERATIVE.lower() == "false":
    _iterative = False

def prompt_if_needed(var, prompt_msg):
    if var is None or var.strip() == "":
        if _iterative:
            var = input(prompt_msg + ": ")
        if var is None or var.strip() == "":
            print(f"{RED}❌ {prompt_msg} cannot be empty{RESET}")
            sys.exit(1)
    return var

gpu = "" if gpu is None else gpu
$GPU = gpu

if "DOCKER_PSSWD" not in $ENV or not $DOCKER_PSSWD.strip():
    print(f"{RED}❌ DOCKER_PSSWD not set{RESET}")
    sys.exit(1)
psswd = $DOCKER_PSSWD

if "TORIZON_ARCH" not in $ENV or not $TORIZON_ARCH.strip():
    print(f"{RED}❌ TORIZON_ARCH not set{RESET}")
    sys.exit(1)

TORIZON_ARCH = $TORIZON_ARCH
if TORIZON_ARCH == "aarch64":
    TORIZON_ARCH = "arm64"
elif TORIZON_ARCH == "armv7l":
    TORIZON_ARCH = "arm"
elif TORIZON_ARCH == "x86_64":
    TORIZON_ARCH = "amd64"
elif TORIZON_ARCH == "riscv":
    TORIZON_ARCH = "riscv64"

imageArch = TORIZON_ARCH

if "APP_ROOT" not in $ENV or not $APP_ROOT.strip():
    print(f"{RED}❌ APP_ROOT not set{RESET}")
    sys.exit(1)
appRoot = $APP_ROOT

compoFilePath = prompt_if_needed(compoFilePath, "docker-compose.yml root file path")
dockerLogin = prompt_if_needed(dockerLogin, "Docker image repository")
psswd = prompt_if_needed(psswd, "Docker registry password")
imageName = prompt_if_needed(imageName, "Docker image name")
tag = prompt_if_needed(tag, "Docker image tag")

if ("TASKS_CUSTOM_SETTINGS_JSON" not in $ENV or $TASKS_CUSTOM_SETTINGS_JSON == "settings.json"):
    $TASKS_CUSTOM_SETTINGS_JSON = "settings.json"
else:
    print("ℹ️ :: CUSTOM SETTINGS :: ℹ️")
    print(f"Using custom settings file: {$TASKS_CUSTOM_SETTINGS_JSON}")

settings_path = f"{compoFilePath}/.vscode/{os.environ['TASKS_CUSTOM_SETTINGS_JSON']}"
if not os.path.exists(settings_path):
    print(f"{RED}❌ {settings_path} does not exist{RESET}")
    sys.exit(1)

with open(settings_path, "r", encoding="utf-8") as f:
    objSettings = yaml.safe_load(f)

localRegistry = objSettings.get("host_ip", None)
if localRegistry is None:
    # host_ip not found
    print(f"{RED}❌ host_ip not found in settings{RESET}")
    sys.exit(1)

$LOCAL_REGISTRY = f"{localRegistry}:5002"
$TAG = tag
if (registry is None or registry.strip() == "" or registry == "registry-1.docker.io"):
    $DOCKER_LOGIN = dockerLogin
else:
    $DOCKER_LOGIN = f"{registry}/{dockerLogin}"

# Build image
print(f"Rebuilding {$DOCKER_LOGIN}/{imageName}:{tag} ...")
os.chdir(compoFilePath)

r = !(docker compose build --build-arg APP_ROOT=@(appRoot) --build-arg IMAGE_ARCH=@(imageArch) --build-arg GPU=@(gpu) @(imageName))
if r.returncode != 0:
    print(f"{RED}❌ docker compose build failed{RESET}")
    sys.exit(r.returncode)

os.chdir("-")

print(f"{GREEN}✅ Image rebuilt and tagged{RESET}")

# Push image
print(f"Pushing it {$DOCKER_LOGIN}/{imageName}:{tag} ...")

login_cmd = f"echo '{psswd}' | docker login {registry or ''} -u {dockerLogin} --password-stdin"
login_res = !(echo @(psswd) | docker login @(registry) -u @(dockerLogin) --password-stdin)
if login_res.returncode != 0:
    print(f"{RED}❌ docker login failed{RESET}")
    sys.exit(login_res.returncode)

push_res = !(docker push {$DOCKER_LOGIN}/{imageName}:{tag})
if push_res.returncode != 0:
    print(f"{RED}❌ docker push failed{RESET}")
    sys.exit(push_res.returncode)

print(f"{GREEN}✅ Image push OK{RESET}")

# In PowerShell: checks if powershell-yaml is installed and installs it if not.
# In Xonsh: we assume PyYAML is installed. If not, `pip install pyyaml`.

print("Reading docker-compose.yml file ...")
compose_path = f"{compoFilePath}/docker-compose.yml"
if not os.path.exists(compose_path):
    print(f"{RED}❌ {compose_path} not found{RESET}")
    sys.exit(1)

with open(compose_path, "r", encoding="utf-8") as f:
    composeLoad = yaml.safe_load(f)

print(f"{GREEN}✅ docker-compose.yml loaded{RESET}")

# The script assumes Services key?
# Normally docker-compose uses 'services'
# We'll assume lowercase 'services' as standard
if 'services' not in composeLoad:
    print(f"{RED}❌ No 'services' key in docker-compose.yml{RESET}")
    sys.exit(1)

composeServices = composeLoad['services']

print("Cleaning services ...")

removeKeys = []
prodKeys = []
for key in list(composeServices.keys()):
    if "debug" in key:
        removeKeys.append(key)
    else:
        prodKeys.append(key)

for k in removeKeys:
    del composeServices[k]

print(f"{GREEN}✅ services cleaned{RESET}")

print("Replacing variables ...")

for key in prodKeys:
    service = composeServices[key]
    # remove 'build' key if present
    if 'build' in service:
        del service['build']
    # replace ${DOCKER_LOGIN}, ${TAG}, ${GPU}
    if 'image' in service:
        img = service['image']
        img = img.replace("${DOCKER_LOGIN}", $DOCKER_LOGIN)
        img = img.replace("${TAG}", tag)
        img = img.replace("${GPU}", gpu)
        service['image'] = img

print(f"{GREEN}✅ variables replaced{RESET}")

prod_path = f"{compoFilePath}/docker-compose.prod.yml"
with open(prod_path, "w", encoding="utf-8") as f:
    yaml.safe_dump(composeLoad, f, default_flow_style=False, sort_keys=False)

print(f"{GREEN}✅ docker-compose.prod.yml created{RESET}")
