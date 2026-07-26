#!/usr/bin/env python3
"""Check every skill against its own `allowed-tools` declaration.

Why this exists
---------------
A skill body is a set of instructions; `allowed-tools` is what pre-approves them.
Nothing tied the two together, and the gap is quiet rather than loud: the skill
reads fine, then a documented step stops to ask for a permission the author
meant to grant — and in a non-interactive session, where nobody can answer, it
does not run at all. Three real defects were found this way in one pass:

  * `write-workflow` instructed `gh issue view` and Sourcerer lookups while its
    allowlist permitted neither
  * the worktree skills, since removed, piped git output through `grep`/`head`/
    `sed` and ran bare `cat`/`pwd` steps, none of them permitted
  * `pull-request` invokes the `code-review` skill without the `Skill` tool

So: for each skill, take the commands its own bash blocks run and the tools its
own prose tells the model to use, and require the declaration to cover them.

Commands hide in prose too — a step written as `python3 …/next-phase.py` in a
sentence needs the same permission as one inside a fence, and reading only
fences made the check a guarantee with a hole in it. Inline spans are scanned
as well, under a stricter rule: prose is full of words that look like commands,
so a span counts only when it opens with a token from KNOWN_COMMANDS.

Usage: check_allowlists.py <skills-dir>
Prints one line per finding; exit status is the number of findings (0 = clean).
"""
import pathlib
import re
import sys

# Shell keywords, builtins and test syntax — never a `Bash(prefix:*)` entry.
SHELL_WORDS = {
    'if', 'then', 'else', 'elif', 'fi', 'for', 'while', 'until', 'do', 'done',
    'case', 'esac', 'in', 'break', 'continue', 'exit', 'return', 'echo',
    'printf', 'read', 'local', 'export', 'set', 'unset', 'shift', 'trap',
    'eval', 'source', 'test', 'true', 'false', 'wait', 'exec', 'time', '[',
}

# Executables a span has to open with before prose counts as an instruction.
# Inside a fence every word in command position is one; in prose `main`,
# `develop`, `done`, `print` and friends are not, so only names that are
# actually programs are read as such. Deliberately absent: `claude` and `code`.
# The skills name those as things — the session a human launches, the editor
# CLI that cannot close its own window — never as a step to run, so every
# inline hit on them is a false positive. Fences still catch them.
KNOWN_COMMANDS = {
    'awk', 'basename', 'bash', 'black', 'cat', 'cd', 'chmod', 'command', 'cp',
    'curl', 'cut', 'date', 'df', 'diff', 'dirname', 'du', 'find', 'flake8',
    'gh', 'git', 'grep', 'head', 'jq', 'kill', 'ln', 'ls', 'make', 'mkdir',
    'mv', 'mypy', 'node', 'npm', 'npx', 'open', 'pip', 'pip3', 'ps', 'pwd',
    'pytest', 'python', 'python3', 'realpath', 'rm', 'rmdir', 'ruff', 'sed',
    'sh', 'sleep', 'sort', 'tail', 'tee', 'touch', 'tr', 'uniq', 'wc', 'which',
    'xargs', 'yarn',
}

# A tool is required when the body tells the model to use it. Keep the patterns
# specific: a bare mention of the word "write" is not an instruction.
TOOL_HINTS = {
    'AskUserQuestion': r'AskUserQuestion',
    'Agent': r'Agent tool|subagent',
    'Skill': r'Skill tool',
}
# Any MCP call named in a body, by server. Was hardcoded to the one MCP the
# skills used to reach for; a public plugin should not know which MCP that is,
# and the rule is the same for all of them.
MCP_CALL = re.compile(r'\bmcp__([a-z0-9_-]+)__')
# "do NOT use AskUserQuestion" is a prohibition, not a requirement. `/auto-phase`
# forbids exactly that, and counting it as a use would demand the tool it bans.
NEGATION = re.compile(r'\b(?:NOT|not|never|Never|no|No|without|senza)\b')


def split_frontmatter(text):
    """(frontmatter, body) — frontmatter is None when the file has none."""
    if not text.startswith('---\n'):
        return None, text
    end = text.find('\n---\n', 3)
    if end == -1:
        return None, text
    return text[4:end], text[end + 5:]


def declared_tools(frontmatter):
    m = re.search(r'^allowed-tools:\s*(.+)$', frontmatter, re.M)
    return [t.strip() for t in m.group(1).split(',') if t.strip()] if m else []


def bash_prefixes(tools):
    """Permitted command prefixes, or None when Bash is unrestricted."""
    if 'Bash' in tools:
        return None
    return {m.group(1) for m in (re.match(r'Bash\(([^:)]+)', t) for t in tools) if m}


def command_words(text):
    """First word of every command in a one-line shell fragment."""
    words = set()
    for seg in re.split(r'\|\||&&|[|;]', text):
        seg = seg.strip().lstrip('!(').strip()
        first = seg.split(' ', 1)[0]
        if not first or '=' in first:               # VAR=value assignment
            continue
        m = re.match(r'^([A-Za-z_\[][\w./-]*)$', first)
        if m:
            words.add(m.group(1))
    return words


def inline_commands(body):
    """Commands the skill instructs in prose, inside single-backtick spans.

    Only a span opening with a KNOWN_COMMANDS token is read as an invocation,
    and only known executables are collected from it — enough for the pipes a
    span like `git worktree list | head -1 | sed …` really needs, without
    promoting placeholders such as `<name>` or `<parent>` to commands.

    A bare token with no arguments is a mention, not an instruction: prose says
    "would only cost a `cd`" and "the `git` history" about the things, not about
    running them. Requiring an argument keeps those out; a fence still catches
    the real single-word invocations.
    """
    prose = re.sub(r'```.*?```', '', body, flags=re.S)
    cmds = set()
    for m in re.finditer(r'(?<!`)`([^`\n]+)`(?!`)', prose):
        span = m.group(1).strip()
        if len(span.split()) < 2:
            continue
        if span.split(' ', 1)[0] not in KNOWN_COMMANDS:
            continue
        cmds |= command_words(span) & KNOWN_COMMANDS
    return cmds - SHELL_WORDS


def commands_used(body):
    """Command words the skill's own bash blocks invoke."""
    cmds = set()
    for block in re.findall(r'```(?:bash|sh)\n(.*?)```', body, re.S):
        heredoc = None
        for line in block.splitlines():
            if heredoc is not None:                     # inside a heredoc body
                if line.strip() == heredoc:
                    heredoc = None
                continue
            h = re.search(r"<<-?\s*'?([A-Za-z_][A-Za-z0-9_]*)'?", line)
            stripped = line.strip()
            if not stripped or stripped.startswith('#'):
                if h:
                    heredoc = h.group(1)
                continue
            # command substitutions run their own command
            cmds.update(re.findall(r'\$\(\s*([A-Za-z_][\w./-]*)', stripped))
            cmds |= command_words(stripped)
            if h:
                heredoc = h.group(1)
    return {c for c in cmds if c not in SHELL_WORDS}


def instructed(body, hint):
    """True when at least one mention of `hint` is not a prohibition."""
    for line in body.splitlines():
        m = re.search(hint, line)
        if m and not NEGATION.search(line[:m.start()]):
            return True
    return False


def check(skills_dir):
    findings = []
    for path in sorted(pathlib.Path(skills_dir).glob('*/SKILL.md')):
        name = path.parent.name
        frontmatter, body = split_frontmatter(path.read_text(encoding='utf-8'))
        if frontmatter is None:
            findings.append(f'{name}: no YAML frontmatter')
            continue
        tools = declared_tools(frontmatter)
        if not tools:
            findings.append(f'{name}: frontmatter declares no allowed-tools')
            continue
        prefixes = bash_prefixes(tools)
        if prefixes is not None:
            used = commands_used(body) | inline_commands(body)
            for cmd in sorted(used - prefixes):
                findings.append(f'{name}: runs `{cmd}` but allowed-tools has no Bash({cmd}:*)')
        for tool, hint in TOOL_HINTS.items():
            if instructed(body, hint) and tool not in tools:
                findings.append(f'{name}: body instructs {tool} but allowed-tools omits it')
        for server in sorted({mm.group(1) for mm in MCP_CALL.finditer(body)}):
            if instructed(body, rf'mcp__{re.escape(server)}__') \
                    and not any(t.startswith(f'mcp__{server}') for t in tools):
                findings.append(f'{name}: body calls the {server} MCP but allowed-tools omits it')
    return findings


if __name__ == '__main__':
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    found = check(sys.argv[1])
    for f in found:
        print(f)
    print(f'{len(found)} finding(s)')
    sys.exit(min(len(found), 250))
