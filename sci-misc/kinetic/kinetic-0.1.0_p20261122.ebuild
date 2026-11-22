# Copyright 1999-2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

CRATES="
	adler2@2.0.1
	anstream@1.0.0
	anstyle-parse@1.0.0
	anstyle-query@1.1.5
	anstyle-wincon@3.0.11
	anstyle@1.0.14
	arrayvec@0.7.8
	ash@0.38.0+1.3.281
	autocfg@1.5.1
	base64@0.22.1
	base64ct@1.8.3
	bit-set@0.10.0
	bit-vec@0.9.1
	bitflags@2.13.2
	blake3@1.8.7
	block-buffer@0.10.4
	block2@0.6.2
	bytemuck@1.25.2
	byteorder-lite@0.1.0
	cc@1.10.0
	cfg-if@1.0.5
	cfg_aliases@0.2.2
	clap@4.6.7
	clap_builder@4.6.7
	clap_derive@4.6.7
	clap_lex@1.1.1
	clipboard-win@5.4.3
	codespan-reporting@0.13.1
	color_quant@1.1.0
	colorchoice@1.0.5
	const-oid@0.9.6
	constant_time_eq@0.4.2
	cpufeatures@0.2.17
	cpufeatures@0.3.1
	crc32fast@1.5.3
	crossbeam-deque@0.8.8
	crossbeam-epoch@0.9.21
	crossbeam-utils@0.8.23
	crunchy@0.2.4
	crypto-common@0.1.7
	ctrlc@3.5.2
	curve25519-dalek-derive@0.1.1
	curve25519-dalek@4.1.3
	der@0.7.10
	digest@0.10.7
	dispatch2@0.3.1
	displaydoc@0.2.7
	ed25519-dalek@2.2.0
	ed25519@2.2.3
	either@1.19.0
	equivalent@1.0.3
	error-code@3.4.0
	fdeflate@0.3.7
	fiat-crypto@0.2.9
	find-msvc-tools@0.1.15
	flate2@1.1.10
	foldhash@0.2.0
	form_urlencoded@1.2.2
	generic-array@0.14.7
	getrandom@0.2.17
	getrandom@0.3.4
	gif@0.14.2
	half@2.7.1
	hashbrown@0.17.1
	heck@0.5.0
	icu_collections@2.4.0
	icu_locale_core@2.4.0
	icu_normalizer@2.4.0
	icu_normalizer_data@2.4.0
	icu_properties@2.4.0
	icu_properties_data@2.4.0
	icu_provider@2.4.0
	idna@1.1.0
	idna_adapter@1.2.2
	image-webp@0.2.4
	image@0.25.10
	indexmap@2.14.2
	is_terminal_polyfill@1.70.2
	itoa@1.0.18
	libc@0.2.191
	libloading@0.8.9
	libm@0.2.16
	litemap@0.8.3
	log@0.4.34
	memchr@2.8.3
	memmap2@0.9.12
	memo-map@0.3.4
	minijinja-contrib@2.24.0
	minijinja@2.24.0
	miniz_oxide@0.8.9
	miniz_oxide@0.9.1
	moxcms@0.8.1
	naga-types@30.0.1
	naga@30.0.1
	nix@0.31.3
	num-traits@0.2.19
	objc2-core-foundation@0.3.2
	objc2-encode@4.1.0
	objc2-foundation@0.3.2
	objc2-metal@0.3.2
	objc2@0.6.5
	once_cell@1.21.4
	once_cell_polyfill@1.70.2
	percent-encoding@2.3.2
	pkcs8@0.10.2
	png@0.18.1
	potential_utf@0.1.6
	proc-macro2@1.0.107
	pxfm@0.1.30
	quick-error@2.0.1
	quote@1.0.47
	r-efi@5.3.0
	rand_core@0.6.4
	rayon-core@1.13.0
	rayon@1.12.0
	rustc-hash@1.1.0
	rustc_version@0.4.1
	rustyline@19.0.0
	semver@1.0.28
	serde@1.0.229
	serde_core@1.0.229
	serde_derive@1.0.229
	serde_json@1.0.154
	sha2@0.10.9
	shlex@2.0.1
	signature@2.2.0
	simd-adler32@0.3.10
	smallvec@1.16.4
	spirv@0.4.0+sdk-1.4.341.0
	spki@0.7.3
	stable_deref_trait@1.2.1
	strsim@0.11.1
	subtle@2.6.1
	syn@2.0.119
	syn@3.0.9
	synstructure@0.14.0
	thiserror-impl@2.0.21
	thiserror@2.0.21
	tinystr@0.8.5
	tinyvec@1.13.3
	typenum@1.20.1
	unicode-general-category@1.1.0
	unicode-ident@1.0.27
	unicode-normalization@0.1.26
	unicode-segmentation@1.13.3
	unicode-width@0.2.3
	ureq@2.12.1
	url@2.5.8
	utf8_iter@1.1.0
	utf8parse@0.2.2
	utf_types@1.0.0
	version_check@0.9.5
	wasi@0.11.1+wasi-snapshot-preview1
	wasip2@1.0.4+wasi-0.2.12
	weezl@0.1.12
	windows-link@0.2.1
	windows-sys@0.61.2
	wit-bindgen@0.57.1
	writeable@0.6.4
	yoke-derive@0.8.4
	yoke@0.8.4
	zerocopy-derive@0.8.63
	zerocopy@0.8.63
	zerofrom-derive@0.1.8
	zerofrom@0.1.8
	zeroize@1.9.1
	zerotrie@0.2.5
	zerovec-derive@0.11.7
	zerovec@0.11.9
	zlib-rs@0.6.8
	zmij@1.0.23
	zune-core@0.5.3
	zune-jpeg@0.5.15
"

RUST_MIN_VER="1.91.0"

inherit cargo

MY_COMMIT="88ef5690b5c91cbcda6fa8e1d7139e1c60eca87d"

DESCRIPTION="Rust inference engine for GGUF models with exact speculative decoding"
HOMEPAGE="https://github.com/Veloresearch/kinetic https://veloresearch.github.io/kinetic/"
SRC_URI="
	https://github.com/Veloresearch/kinetic/archive/${MY_COMMIT}.tar.gz -> ${P}.tar.gz
	${CARGO_CRATE_URIS}
"
S="${WORKDIR}/${PN}-${MY_COMMIT}"

LICENSE="Apache-2.0"
# Dependent crate licenses
LICENSE+=" Apache-2.0 BSD Boost-1.0 ISC MIT Unicode-3.0 ZLIB"
SLOT="0"
KEYWORDS="~amd64"
IUSE="+cuda +vulkan"

# Both backends are opened at runtime (dlopen), so the binary starts on the
# CPU without them; the dependencies make the chosen backend usable.
RDEPEND="
	cuda? ( x11-drivers/nvidia-drivers )
	vulkan? ( media-libs/vulkan-loader )
"
# nvcc compiles the CUDA kernels into the binary; without it the build
# silently ships no kernels.
BDEPEND="cuda? ( dev-util/nvidia-cuda-toolkit )"

QA_FLAGS_IGNORED="usr/bin/${PN}"

src_configure() {
	local myfeatures=(
		$(usev cuda)
		$(usev vulkan)
	)
	cargo_src_configure --no-default-features

	if use cuda; then
		export NVCC="${EPREFIX}/opt/cuda/bin/nvcc"
		[[ -x ${NVCC} ]] || die "nvcc not found at ${NVCC}"
		# Upstream builds every generation from Pascal on; CUDAARCHS from
		# make.conf ("120" or "86;89;120") narrows it to the local cards.
		[[ -n ${CUDAARCHS} ]] && export KINETIC_CUDA_ARCHS="${CUDAARCHS}"
	fi
	# Shown by "kinetic --version" after the package version.
	export KINETIC_BUILD="${PV#*_p} ${MY_COMMIT:0:9}"
}

src_compile() {
	cargo_src_compile --package kinetic-cli
}

src_test() {
	# The suites of the GPU backends need a device; the rest run offline.
	cargo_src_test --workspace --exclude kinetic-cuda --exclude kinetic-vulkan
}

src_install() {
	dobin "$(cargo_target_dir)/${PN}"
	dodoc README.md CHANGELOG.md NOTICE
}

pkg_postinst() {
	elog "\"kinetic serve -m model.gguf ...\" takes llama-server's flags and"
	elog "answers the OpenAI API under /v1. Only \"kinetic pull\" uses the"
	elog "network. Prompt states are cached under ~/.cache/kinetic/warm (up to"
	elog "2 GiB); --no-prompt-cache turns that off."
}
