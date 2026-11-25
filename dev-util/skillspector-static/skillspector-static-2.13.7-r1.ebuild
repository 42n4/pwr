# Copyright 2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

DISTUTILS_USE_PEP517=hatchling
DISTUTILS_SINGLE_IMPL=1
PYTHON_COMPAT=( python3_14 )

inherit distutils-r1

DESCRIPTION="SkillSpector (NVIDIA) skill scanner, static analyzers only, no LLM stack"
HOMEPAGE="https://github.com/NVIDIA/SkillSpector"
SRC_URI="https://github.com/NVIDIA/SkillSpector/archive/refs/tags/v${PV}.tar.gz -> ${P}.gh.tar.gz"
S="${WORKDIR}/SkillSpector-${PV}"

# The name says what this is: upstream's scanner without its LLM, cloud and
# HTTP libraries. A full dev-util/skillspector would be a different package
# (it needs the LangGraph and LangChain family and network access).

LICENSE="Apache-2.0"
SLOT="0"
KEYWORDS="~amd64"
# upstream's suite needs the LLM and HTTP libraries this build leaves out
RESTRICT="test"

# Only what the static analyzers use. Upstream also requires langgraph, four
# langchain packages, langsmith, openai, boto3, google-auth and httpx, and
# imports them even for `scan --no-llm`; files/skillspector_static supplies
# inert stand-ins and a small graph runner, so none of them is installed.
# Upstream pins typer<0.24, regex==2026.5.9 and tree-sitter==0.25.2; the pins
# are dropped after a 37-skill comparison against the pinned set.
RDEPEND="
	sys-apps/bubblewrap
	$(python_gen_cond_dep '
		dev-python/packaging[${PYTHON_USEDEP}]
		>=dev-python/pydantic-2.12[${PYTHON_USEDEP}]
		dev-python/pywhatwgurl[${PYTHON_USEDEP}]
		dev-python/pyyaml[${PYTHON_USEDEP}]
		dev-python/regex[${PYTHON_USEDEP}]
		>=dev-python/rich-14.3[${PYTHON_USEDEP}]
		>=dev-python/tree-sitter-0.25[${PYTHON_USEDEP}]
		>=dev-python/typer-0.23[${PYTHON_USEDEP}]
		>=dev-python/yara-python-4.5[${PYTHON_USEDEP}]
		dev-libs/tree-sitter-bash[python,${PYTHON_USEDEP}]
		dev-libs/tree-sitter-javascript[python,${PYTHON_USEDEP}]
		dev-python/tree-sitter-typescript[${PYTHON_USEDEP}]
	')
"

# libyara 4.5.8 returns only the first instance of a string in fast mode; the
# context filters then drop real matches. Full mode behaves the same on every
# libyara.
PATCHES=( "${FILESDIR}/${P}-yara-full-mode.patch" )

python_prepare_all() {
	distutils-r1_python_prepare_all

	# network-active modules: MCP server and registry client, dependency
	# downloader and its worker, OSV lookup. The stand-in finder serves their
	# names, so the rest of the source still imports.
	rm src/skillspector/{mcp_server,mcp_registry,dependency_downloader,dependency_worker}.py \
		src/skillspector/nodes/analyzers/osv_client.py || die

	# no runtime requirements in the metadata and no unguarded console script:
	# /usr/bin/skillspector is the sandboxed wrapper installed below
	sed -i -e '/^dependencies = \[/,/^\]/d' -e '/^\[project\.scripts\]/,/^$/d' pyproject.toml || die
	grep -q -e '^dependencies' -e '^skillspector = ' pyproject.toml && die "pyproject.toml layout changed"
}

python_install() {
	distutils-r1_python_install
	python_domodule "${FILESDIR}"/skillspector_static
}

python_install_all() {
	distutils-r1_python_install_all

	# read-only filesystem, no network; ~/.skillspector is the writable place
	# for baselines and reports (bound by its real path: upstream refuses an
	# output below a symlinked directory, and the entry point resolves paths).
	cat > "${T}"/${PN} <<-EOF || die
		#!/bin/sh
		[ "\${SKILLSPECTOR_NOBOX:-0}" = 1 ] && exec ${EPYTHON} -m skillspector_static "\$@"
		mkdir -p "\$HOME/.skillspector" || exit 1
		w=\$(realpath "\$HOME/.skillspector") || exit 1
		exec bwrap --ro-bind / / --dev /dev --proc /proc --setenv TMPDIR /dev/shm \\
			--bind "\$w" "\$w" \\
			--unshare-net --unshare-ipc --unshare-pid --die-with-parent --new-session \\
			--chdir "\$PWD" ${EPYTHON} -m skillspector_static "\$@"
	EOF
	dobin "${T}"/${PN}
}

pkg_postinst() {
	elog "skillspector-static is the static scanner only and runs sandboxed (no network,"
	elog "read-only filesystem, ~/.skillspector writable). Every scan runs with"
	elog "--no-llm; remote inputs, --inspect-dependencies, --transitive, the MCP"
	elog "registry options and the MCP server are refused."
}
