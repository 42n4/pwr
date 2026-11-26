# Copyright 2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit edo

DESCRIPTION="Static security scanner for Claude Code configuration (local build)"
HOMEPAGE="https://github.com/affaan-m/agentshield"
SRC_URI="https://github.com/affaan-m/agentshield/archive/refs/tags/v${PV}.tar.gz -> ${P}.tar.gz"

# MIT: agentshield; the bundle inlines its npm dependencies (MIT, ISC, BSD)
LICENSE="MIT ISC BSD"
SLOT="0"
KEYWORDS="~amd64 ~arm64"

# network-sandbox: npm ci fetches the build dependencies, pinned by upstream's
# package-lock.json and installed with --ignore-scripts.
# test: the suite covers the modules this build removes.
RESTRICT="network-sandbox test"

# engines.node >= 20 in package.json
RDEPEND="
	>=net-libs/nodejs-20
	sys-apps/bubblewrap
"
BDEPEND=">=net-libs/nodejs-20[npm]"

# Four local patches plus the directory removal in src_prepare (the same set and
# order as the skilllint WSL container). This build is the
# static scanner only:
#  - removed: --fix (rewrites the scanned config), --opus and --injection (LLM
#    API calls), --sandbox (executes the scanned hooks), --deep, the npm
#    registry lookup of --supply-chain-online, and the commands init, watch
#    (webhook), runtime (installs a hook) and miniclaw (HTTP server)
#  - added: --exclude <path>, to leave third-party trees out of a scan
#  - fixed false alarms: user-scope settings were judged as project scope when
#    the scan root is ~/.claude; one finding per hook line, not per occurrence;
#    a PATH extended only from the login shell or fixed directories is low;
#    a LAN address in the user's own settings is info; autoMode.soft_deny
#    counts as a deny policy; AGENTSHIELD_USER_SCOPE=1 marks a scan root that is
#    someone's own Claude Code directory although it is not ~/.claude of the
#    scanning account (a Windows profile read from Linux); the prompt-defense
#    checks (written for bots facing strangers) report a personal CLAUDE.md at
#    info, not critical
src_prepare() {
	# eapply does not read .xz
	xz -dc "${FILESDIR}/${P}-local.patch.xz" > "${T}/${P}-local.patch" || die
	eapply "${T}/${P}-local.patch"
	eapply "${FILESDIR}/${P}-user-scope-root.patch"
	eapply "${FILESDIR}/${P}-personal-claude-md.patch"
	# A folder named like a config file (a plugin's ".clinerules/") made the
	# discovery read a directory: EISDIR and no report at all.
	eapply "${FILESDIR}/${P}-skip-directories.patch"
	eapply_user
	rm -r src/{opus,llm,fixer,init,miniclaw,watch,runtime,injection,sandbox} || die
}

src_compile() {
	export HOME="${T}"
	export npm_config_cache="${T}/npm-cache"

	edo npm ci --ignore-scripts --no-audit --no-fund
	# tsup -> dist/index.js, one self-contained file
	edo node node_modules/tsup/dist/cli-default.js

	# the bundle must hold no network or process code
	if grep -q -E 'node:(https?|net|dgram|tls|http2|child_process)|await fetch\(' dist/index.js; then
		die "network or process code found in dist/index.js"
	fi
}

src_install() {
	insinto /usr/share/${PN}
	doins dist/index.js

	# read-only filesystem and no network; the one writable place is
	# ~/.agentshield (scan history, baselines, reports)
	cat > "${T}"/${PN} <<-EOF || die
		#!/bin/sh
		[ "\${AGENTSHIELD_NOBOX:-0}" = 1 ] && exec node "${EPREFIX}/usr/share/${PN}/index.js" "\$@"
		mkdir -p "\$HOME/.agentshield" || exit 1
		exec bwrap --ro-bind / / --dev /dev --proc /proc --setenv TMPDIR /dev/shm \\
			--bind "\$HOME/.agentshield" "\$HOME/.agentshield" \\
			--unshare-net --unshare-ipc --unshare-pid --die-with-parent --new-session \\
			--chdir "\$PWD" node "${EPREFIX}/usr/share/${PN}/index.js" "\$@"
	EOF
	dobin "${T}"/${PN}

	dodoc README.md CHANGELOG.md
}

pkg_postinst() {
	elog "agentshield runs sandboxed: no network, read-only filesystem."
	elog "Write baselines and reports below ~/.agentshield, the only writable path:"
	elog "  agentshield scan --path ~/.claude --exclude plugins \\\\"
	elog "      --save-baseline ~/.agentshield/baseline.json"
	elog "  agentshield scan --path ~/.claude --exclude plugins \\\\"
	elog "      --baseline ~/.agentshield/baseline.json --gate"
}
