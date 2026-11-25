# Copyright 2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

DISTUTILS_EXT=1
DISTUTILS_USE_PEP517=setuptools
PYTHON_COMPAT=( python3_{13..14} )

inherit distutils-r1

DESCRIPTION="Python bindings of the TypeScript and TSX grammars for Tree-sitter"
HOMEPAGE="
	https://github.com/tree-sitter/tree-sitter-typescript
	https://pypi.org/project/tree-sitter-typescript/
"
# The sdist on PyPI lacks tree_sitter/parser.h and cannot be built; this is the
# tag tarball, the same distfile dev-libs/tree-sitter-typescript uses.
SRC_URI="https://github.com/tree-sitter/${PN}/archive/v${PV}.tar.gz -> ${P}.tar.gz"

LICENSE="MIT"
SLOT="0"
KEYWORDS="~amd64 ~arm64"

# dev-libs/tree-sitter-typescript builds the C library of one of the two
# grammars and has no Python binding; this is the PyPI source package with
# both (language_typescript, language_tsx). The two install disjoint files.
RDEPEND=">=dev-python/tree-sitter-0.23[${PYTHON_USEDEP}]"
BDEPEND="dev-python/wheel[${PYTHON_USEDEP}]"

distutils_enable_tests import-check
