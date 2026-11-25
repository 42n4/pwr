"""Entry point of the static-only SkillSpector: ``python -m skillspector_static scan PATH ...``."""

from __future__ import annotations

import os
import sys

from skillspector_static import install


def main() -> None:
    install()
    argv = sys.argv[1:]
    if argv and argv[0] in {"mcp", "serve", "mcp-server"}:
        sys.exit("skillspector-static: the MCP server is removed in this static-only build")
    for flag in ("--mcp-registry", "--mcp-registry-compare", "--inspect-dependencies", "--transitive"):
        if flag in argv:
            sys.exit(f"skillspector-static: {flag} needs network access and is removed in this static-only build")
    for arg in argv[1:]:
        if "://" in arg or arg.startswith("git@"):
            sys.exit("skillspector-static: remote inputs need network access; this static-only build scans local paths")
    # Upstream refuses an input or output below a symlinked directory. A home directory reached through a symlink
    # (/home/guest -> /home/pwas) would make every `~/...` argument fail, so local paths are resolved first.
    for i, arg in enumerate(argv):
        if i == 0 or arg.startswith("-"):
            continue
        parent = os.path.dirname(arg) or "."
        if os.path.exists(arg):
            argv[i] = os.path.realpath(arg)
        elif os.sep in arg and os.path.isdir(parent):
            argv[i] = os.path.join(os.path.realpath(parent), os.path.basename(arg))
    if argv and argv[0] in {"scan", "baseline"} and "--no-llm" not in argv:
        argv.append("--no-llm")
    sys.argv = ["skillspector", *argv]
    from skillspector.cli_entry import app

    app()


if __name__ == "__main__":
    main()
