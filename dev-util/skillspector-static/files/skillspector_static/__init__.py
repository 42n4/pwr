"""Static-only runtime for SkillSpector (local addition, not upstream code).

Upstream imports its LLM, cloud and HTTP libraries even for ``scan --no-llm`` and drives the analyzers through
LangGraph. This package lets the unmodified upstream source run without any of them installed:

* ``install()`` puts a meta path finder first that serves inert stand-ins for the blocked libraries. A stand-in can be
  imported, subclassed, used as a decorator or as a type, and nothing else: there is no code behind it, so no request
  can be made through it.
* ``skillspector_static.minigraph`` is served as ``langgraph.graph``: a small in-process runner with the three
  LangGraph features the scan graph uses (nodes, edges, per-key reducers taken from the state annotations).

``python -m skillspector_static ...`` is the entry point; it forces ``--no-llm`` on every scan.
"""

from __future__ import annotations

import importlib.abc
import importlib.machinery
import importlib.util
import sys
import types

# top-level names that must never be the real library in this runtime
BLOCKED = frozenset(
    {
        "anthropic", "boto3", "botocore", "google", "httpx", "langchain_anthropic", "langchain_aws",
        "langchain_core", "langchain_openai", "langsmith", "mcp", "openai", "requests", "tiktoken", "urllib3",
    }
)  # fmt: skip


# upstream modules deleted from this build (LLM providers, MCP server and registry client, dependency downloader and
# its worker, OSV lookup); the rest of the source still imports them, so they are served as stand-ins too
REMOVED_INTERNAL = (
    "skillspector.mcp_server",
    "skillspector.mcp_registry",
    "skillspector.dependency_downloader",
    "skillspector.dependency_worker",
    "skillspector.nodes.analyzers.osv_client",
)


def _is_removed_internal(fullname: str) -> bool:
    return any(fullname == m or fullname.startswith(m + ".") for m in REMOVED_INTERNAL)


class _StubMeta(type):
    def __getattr__(cls, name: str):
        if name.startswith("__") and name.endswith("__"):
            raise AttributeError(name)
        return Stub

    def __getitem__(cls, _key):
        return cls


class Stub(Exception, metaclass=_StubMeta):
    """Stand-in for any class, function, decorator or constant of a blocked library."""

    def __new__(cls, *args, **kwargs):
        if cls is Stub and len(args) == 1 and not kwargs and callable(args[0]) and not isinstance(args[0], type):
            return args[0]  # used as a bare decorator
        return super().__new__(cls)

    def __init__(self, *args, **kwargs):
        pass

    def __call__(self, *args, **kwargs):
        if len(args) == 1 and not kwargs and callable(args[0]):
            return args[0]  # used as a decorator factory
        raise RuntimeError("this build of SkillSpector is static-only: LLM, cloud and HTTP libraries are removed")

    def __getattr__(self, name: str):
        if name.startswith("__") and name.endswith("__"):
            raise AttributeError(name)
        return Stub()

    def __bool__(self) -> bool:
        return False


class _StubModule(types.ModuleType):
    def __getattr__(self, name: str):
        if name.startswith("__") and name.endswith("__"):
            raise AttributeError(name)
        return Stub


class _Finder(importlib.abc.MetaPathFinder, importlib.abc.Loader):
    def find_spec(self, fullname, path=None, target=None):
        top = fullname.partition(".")[0]
        if fullname == "langgraph" or fullname == "langgraph.graph":
            return importlib.machinery.ModuleSpec(fullname, self, is_package=fullname == "langgraph")
        if top == "langgraph" or top in BLOCKED or _is_removed_internal(fullname):
            return importlib.machinery.ModuleSpec(fullname, self, is_package=True)
        return None

    def create_module(self, spec):
        if spec.name == "langgraph.graph":
            from skillspector_static import minigraph

            return minigraph
        module = _StubModule(spec.name)
        module.__path__ = []  # a package, so any submodule import resolves through this finder too
        return module

    def exec_module(self, module):
        return None


def install() -> None:
    if not any(isinstance(f, _Finder) for f in sys.meta_path):
        sys.meta_path.insert(0, _Finder())
