#!/usr/bin/env xonsh

# Copyright (c) 2025 Toradex
# SPDX-License-Identifier: MIT

##
# This script is used to generate and apply docker-compose.yml device rules
##

# use the xonsh environment to update the OS environment
$UPDATE_OS_ENVIRON = True
# Get the full log of error
$XONSH_SHOW_TRACEBACK = True
# always return if a cmd fails
$XONSH_SUBPROC_CMD_RAISE_ERROR = True

import json
import os
import sys
from pathlib import Path
import hashlib

from torizon_templates_utils.colors import Color, print
from ruamel.yaml import YAML
from ruamel.yaml.comments import CommentedSeq
from ruamel.yaml.scalarstring import PlainScalarString

yaml = YAML()
yaml.preserve_quotes = True
yaml.indent(mapping=2, sequence=4, offset=2)

# Unique per workspace (avoids multi-root collisions)
WORKSPACE_ID = hashlib.md5(str(Path.cwd()).encode()).hexdigest()

DIFF_ROOT = Path("/tmp/compose-diffs") / WORKSPACE_ID
COMPOSE_FILE = Path("docker-compose.yml")


def normalize_yaml(text):
    from io import StringIO
    data = yaml.load(text)
    stream = StringIO()
    yaml.dump(data, stream)
    return stream.getvalue().strip()


def load_rules():
    rules_path = Path(__file__).parent / "compose-rules.json"
    if not rules_path.exists():
        return {}
    with open(rules_path) as f:
        return json.load(f)


def strip_managed_rules_from_text(text, rules):
    rule_comments = {r["rule"]: r["comment"] for v in rules.values() for r in v}

    lines = text.splitlines()
    result = []

    for line in lines:
        stripped = line.strip()

        matched_rule = next(
            (rule for rule in rule_comments
             if stripped == f'- "{rule}"' or stripped == f'- {rule}'),
            None
        )

        if matched_rule is not None:
            expected_comment = f'# {rule_comments[matched_rule]}'
            if result and result[-1].strip() == expected_comment:
                result.pop()
            continue

        result.append(line)

    return "\n".join(result) + "\n"


def get_indent_from_seq(seq, parent_map=None):
    # lc.data[idx][1] is the value column (after "- "), subtract 2 for the dash
    try:
        if seq.lc.data:
            return seq.lc.data[0][1] - 2
    except Exception:
        pass

    # lc.col is unreliable for flow sequences (returns column of "[")
    # so fall back to parent mapping key column + 2
    try:
        if parent_map is not None and parent_map.lc.data:
            key_col = next(iter(parent_map.lc.data.values()))[1]
            return key_col + 2
    except Exception:
        pass

    return 6


def generate_for_file(compose_path, device_name):
    original_text = compose_path.read_text()

    rules = load_rules()

    device_name = (device_name or "").strip().lower()

    matched_key = next(
        (k for k in rules if k.lower() in device_name),
        None
    )

    selected_rules = rules.get(matched_key, []) if matched_key else []

    cleaned_text = strip_managed_rules_from_text(original_text, rules)

    doc = yaml.load(cleaned_text)
    if not doc or "services" not in doc:
        return None

    services = doc["services"]

    for service_name in services:
        service = services[service_name]

        seq = service.get("device_cgroup_rules")

        if not isinstance(seq, CommentedSeq):
            seq = CommentedSeq()
            service["device_cgroup_rules"] = seq

        indent_col = get_indent_from_seq(seq, service)

        for r in selected_rules:
            value = PlainScalarString(r["rule"])
            seq.append(value)

            seq.yaml_set_comment_before_after_key(
                len(seq) - 1,
                before=r["comment"],
                indent=indent_col
            )

    from io import StringIO
    stream = StringIO()
    yaml.dump(doc, stream)
    updated_text = stream.getvalue()

    if normalize_yaml(original_text) == normalize_yaml(updated_text):
        return None

    return updated_text


def write_diff(updated):
    out_dir = DIFF_ROOT / "docker-compose.yml"
    out_dir.mkdir(parents=True, exist_ok=True)

    (out_dir / "updated.yml").write_text(updated)


def generate(device_name):
    rm -rf @(str(DIFF_ROOT))

    if not COMPOSE_FILE.exists():
        print(
            f"⚠️  {COMPOSE_FILE} not found, skipping.",
            color=Color.YELLOW
        )
        return

    print(
        f"Checking compose rules for device: {device_name or 'upstream'}",
        color=Color.CYAN
    )

    try:
        updated = generate_for_file(COMPOSE_FILE, device_name)
    except Exception as e:
        print(f"❌ Failed to generate compose rules: {e}", color=Color.RED)
        sys.exit(1)

    if updated:
        write_diff(updated)
        print(
            "Suggested compose rules changes are ready for review.",
            color=Color.YELLOW
        )
    else:
        print(
            f"✅ {COMPOSE_FILE} device_cgroup_rules are up to date.",
            color=Color.GREEN
        )


def apply(accept_all=False):
    diff_file = DIFF_ROOT / "docker-compose.yml" / "updated.yml"

    if not diff_file.exists():
        print("✅ No pending compose rules diff to apply.", color=Color.YELLOW)
        return

    if accept_all:
        try:
            cp -f @(str(diff_file)) @(str(COMPOSE_FILE))
            print(
                f"✅ Compose rules applied to {COMPOSE_FILE}.",
                color=Color.GREEN
            )
        except Exception as e:
            print(f"❌ Failed to apply compose rules: {e}", color=Color.RED)
            sys.exit(1)
        return

    vscode = os.environ.get("TERM_PROGRAM") == "vscode" or "VSCODE_PID" in os.environ
    if "TORIZON_TEMPLATES_NON_VSCODE" in os.environ:
        vscode = False

    if vscode:
        print("Opening diff in VS Code...", color=Color.CYAN)
        code --wait --diff @(str(diff_file)) @(str(COMPOSE_FILE))
        print("✅ Diff review complete.", color=Color.GREEN)
    else:
        _meld = $(which meld).strip()
        if not _meld:
            print("❌ meld is not installed.", color=Color.RED)
            sys.exit(1)
        print("Opening diff in meld...", color=Color.CYAN)
        @(_meld) @(str(diff_file)) @(str(COMPOSE_FILE))
        print("✅ Diff review complete.", color=Color.GREEN)


def main():
    args = sys.argv[1:]
    do_generate = "generate" in args
    do_apply = "apply" in args
    accept_all = "--accept-all" in args

    if not do_generate and not do_apply:
        print("Usage: compose-rules.xsh generate [device] | apply [--accept-all] | generate apply [device] [--accept-all]")
        return

    keywords = {"generate", "apply", "--accept-all"}
    device = next((a for a in args if a not in keywords), "")

    if do_generate:
        generate(device)
    if do_apply:
        apply(accept_all)


if __name__ == "__main__":
    main()
