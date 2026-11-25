# Copyright 2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit edo

DESCRIPTION="Linter for AI agent context files, MCP configs and Claude Code skills (YawLabs)"
HOMEPAGE="https://github.com/YawLabs/ctxlint"
SRC_URI="https://github.com/YawLabs/ctxlint/archive/refs/tags/v${PV}.tar.gz -> ${P}.tar.gz"
S="${WORKDIR}/ctxlint-${PV}"

# MIT: ctxlint; the bundle inlines its npm dependencies (MIT, ISC, BSD, Apache-2.0)
LICENSE="MIT ISC BSD BSD-2 Apache-2.0"
SLOT="0"
KEYWORDS="~amd64 ~arm64"

# network-sandbox: npm ci fetches the build dependencies (esbuild and what it
# bundles). They are pinned by the lock file in files/ and installed with
# --ignore-scripts, so no package runs code at install time.
# test: the vitest suite needs git repositories and a writable home.
RESTRICT="network-sandbox test"

# engines.node >= 20 in package.json; git: staleness and rename lookups
RDEPEND="
	>=net-libs/nodejs-20
	dev-vcs/git
	sys-apps/bubblewrap
"
BDEPEND=">=net-libs/nodejs-20[npm]"

# no-fix: the --fix/--fix-dry-run/--yes/--follow-symlinks options and the MCP
#   tool ctxlint_fix are removed and applyFixes only previews. Its fuzzy
#   matcher rewrote curated context files with wrong paths.
# local-fixes: paths check (slash-joined prose, option lists, numbers,
#   extension lists, scheme-less URLs; a reference found deeper in the tree
#   is a note, not an error) and skills check (bare references/ scripts/
#   assets/ paths are validated).
PATCHES=(
	"${FILESDIR}/${P}-no-fix.patch"
	"${FILESDIR}/${P}-local-fixes.patch"
)

src_prepare() {
	default
	# upstream locks with pnpm only; this is the npm lock of the same tree
	xz -dc "${FILESDIR}/${P}-package-lock.json.xz" > package-lock.json || die
}

src_compile() {
	export HOME="${T}"
	export npm_config_cache="${T}/npm-cache"

	edo npm ci --ignore-scripts --no-audit --no-fund
	# esbuild -> dist/index.js, one self-contained file
	edo node build.mjs
}

src_install() {
	insinto /usr/share/${PN}
	doins dist/index.js

	# Never upstream's bin/ctxlint.mjs: that launcher searches the machine for
	# another runtime (oam) and runs the linter through it. The bundle runs on
	# the system Node.js inside bwrap: read-only filesystem, no network.
	cat > "${T}"/${PN} <<-EOF || die
		#!/bin/sh
		[ "\${CTXLINT_NOBOX:-0}" = 1 ] && exec node "${EPREFIX}/usr/share/${PN}/index.js" "\$@"
		exec bwrap --ro-bind / / --dev /dev --proc /proc --tmpfs /tmp \\
			--unshare-net --unshare-ipc --unshare-pid --die-with-parent --new-session \\
			--chdir "\$PWD" node "${EPREFIX}/usr/share/${PN}/index.js" "\$@"
	EOF
	dobin "${T}"/${PN}

	dodoc README.md CHANGELOG.md
}

pkg_postinst() {
	elog "ctxlint-yaw runs sandboxed (no network, read-only filesystem)."
	elog "CTXLINT_NOBOX=1 runs it bare, e.g. for the language server (--lsp)."
	elog "The fix feature is removed in this build."
}
