"""The part of ``langgraph.graph`` the SkillSpector scan graph uses, without LangGraph (local addition)."""

from __future__ import annotations

import inspect
from collections.abc import Iterator
from typing import Annotated, Any, get_args, get_origin, get_type_hints

START = "__start__"
END = "__end__"


def _reducers(schema: Any) -> dict[str, Any]:
    out: dict[str, Any] = {}
    try:
        hints = get_type_hints(schema, include_extras=True)
    except Exception:  # an annotation naming a removed library: fall back to the raw annotations
        hints = getattr(schema, "__annotations__", {})
    for key, hint in hints.items():
        node = hint
        while get_origin(node) is not None and get_origin(node) is not Annotated:
            args = get_args(node)  # NotRequired[Annotated[...]] and the like
            if len(args) != 1:
                break
            node = args[0]
        if get_origin(node) is Annotated:
            meta = [m for m in get_args(node)[1:] if callable(m)]
            if meta:
                out[key] = meta[-1]
    return out


class _Compiled:
    def __init__(self, nodes: dict[str, Any], edges: list[tuple[str, str]], reducers: dict[str, Any]) -> None:
        self._nodes = nodes
        self._edges = edges
        self._reducers = reducers

    def _apply(self, state: dict[str, Any], update: Any) -> None:
        if not isinstance(update, dict):
            return
        for key, value in update.items():
            reducer = self._reducers.get(key)
            if reducer is None:
                state[key] = value
            elif key in state:
                state[key] = reducer(state[key], value)
            else:
                state[key] = reducer([], value) if isinstance(value, list) else value

    def _call(self, name: str, state: dict[str, Any], config: Any) -> Any:
        fn = self._nodes[name]
        try:
            params = inspect.signature(fn).parameters
        except (TypeError, ValueError):
            params = {}
        output = fn(dict(state), config) if "config" in params else fn(dict(state))
        for callback in (config or {}).get("callbacks") or []:
            hook = getattr(callback, "on_chain_end", None)
            if callable(hook):
                hook(output)
        return output

    def _run(self, initial: Any, config: Any) -> Iterator[tuple[str, Any]]:
        state: dict[str, Any] = {}
        self._apply(state, dict(initial or {}))
        order = {name: i for i, name in enumerate(self._nodes)}
        frontier = [b for a, b in self._edges if a == START]
        while frontier:
            step = sorted({n for n in frontier if n != END}, key=lambda n: order[n])
            if not step:
                break
            # every node of a step sees the state as it was before the step, like a LangGraph superstep
            before = dict(state)
            outputs = [(name, self._call(name, before, config)) for name in step]
            for name, output in outputs:
                self._apply(state, output)
                yield "updates", {name: output}
            yield "values", dict(state)
            done = set(step)
            frontier = [b for a, b in self._edges if a in done]
        yield "final", state

    def invoke(self, state: Any, config: Any = None, **_kwargs: Any) -> dict[str, Any]:
        final: dict[str, Any] = {}
        for mode, chunk in self._run(state, config):
            if mode == "final":
                final = chunk
        return final

    async def ainvoke(self, state: Any, config: Any = None, **kwargs: Any) -> dict[str, Any]:
        return self.invoke(state, config, **kwargs)

    def stream(self, state: Any, config: Any = None, stream_mode: Any = "values", **_kwargs: Any) -> Iterator[Any]:
        modes = [stream_mode] if isinstance(stream_mode, str) else list(stream_mode)
        for mode, chunk in self._run(state, config):
            if mode in modes:
                yield (mode, chunk) if not isinstance(stream_mode, str) else chunk


class StateGraph:
    def __init__(self, state_schema: Any = None, *_args: Any, **_kwargs: Any) -> None:
        self._schema = state_schema
        self._nodes: dict[str, Any] = {}
        self._edges: list[tuple[str, str]] = []

    def add_node(self, name: str, action: Any = None, **_kwargs: Any) -> "StateGraph":
        if name in self._nodes:
            raise ValueError(f"node {name!r} is already present")
        self._nodes[name] = action
        return self

    def add_edge(self, start: str, end: str) -> "StateGraph":
        self._edges.append((start, end))
        return self

    def compile(self, *_args: Any, **_kwargs: Any) -> _Compiled:
        return _Compiled(dict(self._nodes), list(self._edges), _reducers(self._schema))
