# Copyright 2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

COMMIT="0a6e86a4e4256816ce417b952063382e0dc45c60"

DESCRIPTION="Linter for AI agent context files: README overlap, inferable content"
HOMEPAGE="https://github.com/ctxlint/Ctxlint"
SRC_URI="https://github.com/ctxlint/Ctxlint/archive/${COMMIT}.tar.gz -> ${P}.tar.gz"
S="${WORKDIR}/Ctxlint-${COMMIT}"

LICENSE="MIT"
SLOT="0"
KEYWORDS="~amd64 ~arm64"
# upstream's suite needs vitest from the npm registry
RESTRICT="test"

# engines.node >= 18 in package.json; plain JavaScript, no build step and,
# with the local patch, no runtime dependency (commander is replaced)
RDEPEND="
	>=net-libs/nodejs-18
	sys-apps/bubblewrap
"

# One local patch (upstream has been silent since 2026-04-13):
#  - init, slim (they write files), diff and mcp commands removed
#  - rules stale-command and ci-coverage not registered, stale-file-ref kept
#    for absolute and ~ paths only: dev-util/ctxlint-yaw does the rest better
#  - token-budget counts a flagged line once and only for "removable" rules;
#    the made-up team cost projection is gone
PATCHES=( "${FILESDIR}/${P}-local.patch" )

src_prepare() {
	default
	rm src/commands/{init,slim,diff,mcp}.js || die
	rm src/rules/{stale-command,ci-coverage}.js || die
	rm -r src/rules/mcp src/detector/mcp.js src/reporter/mcp-terminal.js || die
}

src_install() {
	insinto /usr/share/${PN}
	doins -r bin src package.json

	# read-only filesystem and no network: the linter needs neither
	cat > "${T}"/${PN} <<-EOF2 || die
		#!/bin/sh
		[ "\${CTXLINT_NOBOX:-0}" = 1 ] && exec node "${EPREFIX}/usr/share/${PN}/bin/ctxlint.js" "\$@"
		exec bwrap --ro-bind / / --dev /dev --proc /proc --tmpfs /tmp \\
			--unshare-net --unshare-ipc --unshare-pid --die-with-parent --new-session \\
			--chdir "\$PWD" node "${EPREFIX}/usr/share/${PN}/bin/ctxlint.js" "\$@"
	EOF2
	dobin "${T}"/${PN}

	dodoc README.md
}
