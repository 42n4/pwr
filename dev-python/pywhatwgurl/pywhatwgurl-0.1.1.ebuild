# Copyright 2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

DISTUTILS_USE_PEP517=hatchling
PYTHON_COMPAT=( python3_{13..14} )

inherit distutils-r1 pypi

DESCRIPTION="Pure Python implementation of the WHATWG URL Standard"
HOMEPAGE="
	https://github.com/pywhatwgurl/pywhatwgurl
	https://pypi.org/project/pywhatwgurl/
"

LICENSE="MIT"
SLOT="0"
KEYWORDS="~amd64 ~arm64"
# the conformance suite reads fixture files that are not in the sdist
RESTRICT="test"

RDEPEND=">=dev-python/idna-3.4[${PYTHON_USEDEP}]"
BDEPEND="dev-python/hatch-vcs[${PYTHON_USEDEP}]"
