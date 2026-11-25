# Copyright 1999-2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

PYTHON_COMPAT=( python3_{12..15} )
SPHINX_PYTHON_COMPAT=( python3_{13..15} )
PYTHON_REQ_USE='bzip2(+),threads(+)'
TMPFILES_OPTIONAL=1

inherit meson linux-info python-r1 tmpfiles

DESCRIPTION="The package management and distribution system for Gentoo"
HOMEPAGE="https://wiki.gentoo.org/wiki/Project:Portage"

# NOT a git checkout: a snapshot of ONE upstream commit, pinned below (master of
# 2026-11-23), plus the resolver patch series ported to it:
# files/ladder-bdf046b03/ 0001-0034 (the series of -r10/-r11, ported patch by
# patch), 0035-0037 (stage 5 of the agent runs; each of the three applies alone)
# and the C modules. -r11 (73646c35d based) stays as the fallback. To move to a
# newer commit: port the series (files/ladder-bdf046b03/README says how), copy
# the directory under the new short hash, change PORTAGE_COMMIT and the Manifest.
# To leave one of 0035-0037 out, delete that file from the ladder directory.
# Six-state resolve sum: unpatched commit 396.5 s, 0001-0034 87.5 s, this build
# about 74 s; same merge list in order and same backtracking attempts on every
# state. The patches come from agent runs (stated in the header of each patch).
PORTAGE_COMMIT="278020458f0f6ab742ff3e4916c6884f09bb6837"
# -r13 (2026-11-25): upstream master moved nine commits past bdf046b03, all in bin/ shell
# helpers (ebuild.sh, ecompress, isolated-functions.sh, version-functions.sh,
# emerge-webrsync, save-ebuild-env.sh); none touches a file of the series. Every patch of
# ladder-bdf046b03 and both extra patches apply to this commit unchanged (patch -p1 -F0),
# so they are used from that directory instead of a copy.
PATCH_BASE="bdf046b03"
LADDER="ladder-${PATCH_BASE}"
MY_P="${PN}-${PORTAGE_COMMIT}"
# gitweb answered 502 for this snapshot on 2026-11-25; the GitHub mirror has the same tree
SRC_URI="https://github.com/gentoo/portage/archive/${PORTAGE_COMMIT}.tar.gz -> ${MY_P}.gh.tar.gz"
S="${WORKDIR}/${MY_P}"

LICENSE="GPL-2"
SLOT="0"
IUSE="apidoc build doc gentoo-dev +ipc +native-extensions +rsync-verify selinux test xattr"
REQUIRED_USE="
	${PYTHON_REQUIRED_USE}
	apidoc? ( || ( $(python_gen_useflags "${SPHINX_PYTHON_COMPAT[@]}") ) )
"
RESTRICT="!test? ( test )"

BDEPEND="
	${PYTHON_DEPS}
	>=app-arch/tar-1.27
	>=dev-build/meson-1.3.0-r1
	>=sys-apps/sed-4.0.5
	sys-devel/patch
	!build? ( $(python_gen_impl_dep 'ssl(+)') )
	apidoc? (
		$(python_gen_cond_dep '
			dev-python/sphinx[${PYTHON_USEDEP}]
			dev-python/sphinx-epytext[${PYTHON_USEDEP}]
		' "${SPHINX_PYTHON_COMPAT[@]}")
	)
	doc? (
		~app-text/docbook-xml-dtd-4.4
		app-text/xmlto
	)
	test? (
		dev-python/pytest-xdist[${PYTHON_USEDEP}]
		dev-vcs/git
	)
"
# Require sandbox-2.2 for bug #288863.
# For whirlpool hash, require python[ssl] (bug #425046).
RDEPEND="
	${PYTHON_DEPS}
	>=acct-user/portage-0-r4
	>=app-arch/tar-1.27
	app-arch/zstd
	>=app-misc/pax-utils-0.1.17
	dev-lang/python-exec:2
	>=sys-apps/baselayout-2.9
	>=sys-apps/findutils-4.9
	!build? (
		>=app-admin/eselect-1.2
		app-portage/getuto
		>=app-shells/bash-5.3:0
		dev-util/debugedit
		>=sec-keys/openpgp-keys-gentoo-release-20240703
		>=sys-apps/sed-4.0.5
		rsync-verify? (
			app-alternatives/gpg[ssl(-)]
			>=app-portage/gemato-14.5[${PYTHON_USEDEP}]
		)
	)
	kernel_linux? (
		sys-apps/util-linux
		elibc_glibc? ( >=sys-apps/sandbox-2.2 )
		elibc_musl? ( >=sys-apps/sandbox-2.2 )
	)
	selinux? ( >=sys-libs/libselinux-2.0.94[python,${PYTHON_USEDEP}] )
	xattr? ( kernel_linux? (
		>=sys-apps/install-xattr-0.3
	) )
"
# coreutils-6.4 rdep is for date format in emerge-webrsync #164532
# NOTE: FEATURES=installsources requires debugedit and rsync
PDEPEND="
	!build? (
		>=net-misc/rsync-2.6.4
		>=sys-apps/coreutils-6.4
		>=sys-apps/file-5.44-r3
	)
"

# The USER_PATCHES patch of ::gentoo's 3.0.83-r1 is upstream at this commit.
PATCHES=(
	"${FILESDIR}/${LADDER}"
	"${FILESDIR}/${PN}-${PATCH_BASE}-native-fastpaths.patch"
	# parallel unmerge held the config lock while pkg_postrm ran env-update: hang
	"${FILESDIR}/${PN}-${PATCH_BASE}-env-update-below-unmerge-group.patch"
)

pkg_pretend() {
	local CONFIG_CHECK="~IPC_NS ~PID_NS ~NET_NS ~UTS_NS"

	check_extra_config
}

my_python_check_deps() {
	use apidoc || return 0
	python_has_version -b "dev-python/sphinx[${PYTHON_USEDEP}]" &&
		python_has_version -b "dev-python/sphinx-epytext[${PYTHON_USEDEP}]"
}

src_prepare() {
	default

	if use prefix-guest; then
		sed -e "s|^\(main-repo = \).*|\\1gentoo_prefix|" \
			-e "s|^\\[gentoo\\]|[gentoo_prefix]|" \
			-e "s|^\(sync-uri = \).*|\\1rsync://rsync.prefix.bitzolder.nl/gentoo-portage-prefix|" \
			-i cnf/repos.conf || die "sed failed"
	fi
}

src_configure() {
	local code_only=false
	python_foreach_impl my_src_configure
	[[ ${code_only} == false ]] && die "Documentation and additional configuration aren't getting built as expected"
}

my_src_configure() {
	local emesonargs=(
		-Deprefix="${EPREFIX}"
		-Dportage-bindir="${EPREFIX}/usr/lib/portage/${EPYTHON}"
		-Ddocdir="${EPREFIX}/usr/share/doc/${PF}"
		$(meson_use doc)
		$(meson_use apidoc)
		$(meson_use gentoo-dev)
		$(meson_use ipc)
		$(meson_use xattr)
	)

	if use native-extensions && [[ "${EPYTHON}" != pypy3* ]] ; then
		emesonargs+=( -Dnative-extensions=true )
	else
		emesonargs+=( -Dnative-extensions=false )
	fi

	if use build; then
		emesonargs+=( -Drsync-verify=false )
	else
		emesonargs+=( $(meson_use rsync-verify) )
	fi

	if [[ "${code_only}" == "false" ]] && my_python_check_deps; then
		emesonargs+=( -Dcode-only=false )
		code_only=true
	else
		emesonargs+=( -Dcode-only=true )
	fi

	meson_src_configure
}

src_compile() {
	python_foreach_impl meson_src_compile
}

src_test() {
	local EPYTEST_XDIST=1
	local -x PYTEST_DISABLE_PLUGIN_AUTOLOAD=1
	python_foreach_impl epytest
}

src_install() {
	python_foreach_impl my_src_install
	dotmpfiles "${FILESDIR}"/portage-{ccache,tmpdir}.conf

	local scripts
	mapfile -t scripts < <(awk '/^#!.*python/ {print FILENAME} {nextfile}' "${ED}"/usr/{bin,sbin}/* || die)
	python_replicate_script "${scripts[@]}"
}

my_src_install() {
	local pydirs=(
		"${D}$(python_get_sitedir)"
		"${ED}/usr/lib/portage/${EPYTHON}"
	)

	meson_src_install
	python_fix_shebang "${pydirs[@]}"
	python_optimize "${pydirs[@]}"
}

pkg_preinst() {
	if ! use build && [[ -z ${ROOT} ]]; then
		python_setup
		local sitedir=$(python_get_sitedir)
		[[ -d ${D}${sitedir} ]] || die "${D}${sitedir}: No such directory"
		env -u DISTDIR \
			-u PORTAGE_OVERRIDE_EPREFIX \
			-u PORTAGE_REPOSITORIES \
			-u PORTDIR \
			-u PORTDIR_OVERLAY \
			PYTHONPATH="${D}${sitedir}${PYTHONPATH:+:${PYTHONPATH}}" \
			ED="${ED}" \
			"${PYTHON}" -m portage._compat_upgrade.default_locations || die

		env -u BINPKG_COMPRESS -u PORTAGE_REPOSITORIES \
			PYTHONPATH="${D}${sitedir}${PYTHONPATH:+:${PYTHONPATH}}" \
			ED="${ED}" \
			"${PYTHON}" -m portage._compat_upgrade.binpkg_compression || die

		env -u FEATURES -u PORTAGE_REPOSITORIES \
			PYTHONPATH="${D}${sitedir}${PYTHONPATH:+:${PYTHONPATH}}" \
			ED="${ED}" \
			"${PYTHON}" -m portage._compat_upgrade.binpkg_multi_instance || die

		env -u BINPKG_FORMAT \
			PYTHONPATH="${D}${sitedir}${PYTHONPATH:+:${PYTHONPATH}}" \
			ED="${ED}" \
			"${PYTHON}" -m portage._compat_upgrade.binpkg_format || die
	fi

	# elog dir must exist to avoid logrotate error for bug #415911.
	# This code runs in preinst in order to bypass the mapping of
	# portage:portage to root:root which happens after src_install.
	keepdir /var/log/portage/elog
	# This is allowed to fail if the user/group are invalid for prefix users.
	if chown portage:portage "${ED}"/var/log/portage{,/elog} 2>/dev/null ; then
		chmod g+s,ug+rwx "${ED}"/var/log/portage{,/elog}
	fi

	if has_version "<${CATEGORY}/${PN}-2.3.77"; then
		elog "The emerge --autounmask option is now disabled by default, except for"
		elog "portions of behavior which are controlled by the --autounmask-use and"
		elog "--autounmask-license options. For backward compatibility, previous"
		elog "behavior of --autounmask=y and --autounmask=n is entirely preserved."
		elog "Users can get the old behavior simply by adding --autounmask to the"
		elog "make.conf EMERGE_DEFAULT_OPTS variable. For the rationale for this"
		elog "change, see https://bugs.gentoo.org/658648."
	fi
}

pkg_postinst() {
	# Warn about obsolete "enotice" script, bug #867010
	local bashrc=${EROOT}/etc/portage/profile/profile.bashrc
	if [[ -e ${bashrc} ]] && grep -q enotice "${bashrc}"; then
		eerror "Obsolete 'enotice' script detected!"
		eerror "Please remove this from ${bashrc} to avoid problems."
		eerror "See bug 867010 for more details."
	fi
}
