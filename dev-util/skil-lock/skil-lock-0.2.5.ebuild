# Copyright 2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit go-module

DESCRIPTION="Lock file and capability diff for Claude Code and Codex skills"
HOMEPAGE="https://github.com/skills-lock/skil-lock"

EGO_SUM=(
	"github.com/bmatcuk/doublestar/v4 v4.10.0"
	"github.com/bmatcuk/doublestar/v4 v4.10.0/go.mod"
	"github.com/cpuguy83/go-md2man/v2 v2.0.6/go.mod"
	"github.com/inconshreveable/mousetrap v1.1.0"
	"github.com/inconshreveable/mousetrap v1.1.0/go.mod"
	"github.com/russross/blackfriday/v2 v2.1.0/go.mod"
	"github.com/spf13/cobra v1.10.2"
	"github.com/spf13/cobra v1.10.2/go.mod"
	"github.com/spf13/pflag v1.0.9"
	"github.com/spf13/pflag v1.0.9/go.mod"
	"github.com/yuin/goldmark v1.8.5"
	"github.com/yuin/goldmark v1.8.5/go.mod"
	"go.yaml.in/yaml/v3 v3.0.4/go.mod"
	"gopkg.in/check.v1 v0.0.0-20161208181325-20d25e280405"
	"gopkg.in/check.v1 v0.0.0-20161208181325-20d25e280405/go.mod"
	"gopkg.in/yaml.v3 v3.0.1"
	"gopkg.in/yaml.v3 v3.0.1/go.mod"
)
go-module_set_globals

SRC_URI="https://github.com/skills-lock/skil-lock/archive/refs/tags/v${PV}.tar.gz -> ${P}.tar.gz
	${EGO_SUM_SRC_URI}"

LICENSE="Apache-2.0 BSD MIT"
SLOT="0"
KEYWORDS="~amd64 ~arm64"

# A skills root can hold a directory that is not a skill (Codex keeps a
# .system container there); upstream reports it as a parse error and the
# whole check fails. Real parse failures are still reported.
PATCHES=( "${FILESDIR}/${P}-skip-missing-skillmd.patch" )

src_compile() {
	ego build -ldflags "-X main.version=${PV}" -o ${PN} ./cmd/${PN}
}

src_test() {
	ego test ./...
}

src_install() {
	dobin ${PN}
	dodoc README.md SPEC.md
}
