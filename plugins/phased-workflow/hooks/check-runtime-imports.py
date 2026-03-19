#!/usr/bin/env python3
"""Hook PostToolUse: blocca import dentro funzioni/metodi (runtime imports)."""
import ast
import json
import sys


def find_runtime_imports(filepath):
    """Trova import statement dentro function/method bodies."""
    try:
        with open(filepath, "r") as f:
            source = f.read()
        tree = ast.parse(source, filename=filepath)
    except (SyntaxError, FileNotFoundError, UnicodeDecodeError):
        return []

    runtime_imports = []

    for node in ast.walk(tree):
        if not isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef)):
            continue
        for child in ast.walk(node):
            if isinstance(child, (ast.Import, ast.ImportFrom)):
                if isinstance(child, ast.Import):
                    modules = [alias.name for alias in child.names]
                else:
                    mod = child.module or ""
                    modules = [
                        f"{mod}.{alias.name}" if mod else alias.name
                        for alias in child.names
                    ]
                runtime_imports.append(
                    {
                        "line": child.lineno,
                        "function": node.name,
                        "modules": modules,
                    }
                )

    return runtime_imports


def main():
    input_data = json.loads(sys.stdin.read())
    file_path = input_data.get("tool_input", {}).get("file_path", "")

    if not file_path.endswith(".py"):
        return

    issues = find_runtime_imports(file_path)
    if not issues:
        return

    lines = []
    for issue in issues:
        mods = ", ".join(issue["modules"])
        lines.append(f"  riga {issue['line']}: `{mods}` dentro `{issue['function']}()`")

    msg = (
        f"Runtime import trovati in {file_path}:\n"
        + "\n".join(lines)
        + "\n\nSposta gli import a livello di modulo (top of file)."
    )
    print(json.dumps({"decision": "block", "reason": msg}))


if __name__ == "__main__":
    main()
