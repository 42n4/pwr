# Copyright 1999-2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit cmake cuda flag-o-matic toolchain-funcs

MY_COMMIT="b9c5b427d"
MY_REL="1.1.3"	# release that carries the engine source asset

DESCRIPTION="llama.cpp fork that runs Kintsugi-27B (Escha/EXL3 weights, DFlash2 drafting)"
HOMEPAGE="https://github.com/professorpalmer/Kintsugi-27B"
SRC_URI="https://github.com/professorpalmer/Kintsugi-27B/releases/download/v${MY_REL}/Kintsugi-27B-v${PV}-engine-src-${MY_COMMIT}.tar.gz"
S="${WORKDIR}/kintsugi-engine-${MY_COMMIT}"

LICENSE="MIT"
SLOT="0"
KEYWORDS="~amd64"

CPU_FLAGS_X86=(
	avx avx2 avx512_bf16 avx512_vnni avx512f avx512vbmi avx_vnni bmi2 f16c
	fma3 sse4_2
)

IUSE="+cuda debug +openmp +openssl"
IUSE+=" ${CPU_FLAGS_X86[@]/#/cpu_flags_x86_}"

# The backend test needs the GPU and the other suites need model files.
RESTRICT="test"

DEPEND="
	cuda? ( dev-util/nvidia-cuda-toolkit:= )
	openmp? ( llvm-runtimes/openmp:= )
	openssl? ( dev-libs/openssl:= )
"
RDEPEND="${DEPEND}"
BDEPEND="cuda? ( dev-util/nvidia-cuda-toolkit )"

pkg_pretend() {
	[[ ${MERGE_TYPE} != binary ]] && use openmp && tc-check-openmp
}

pkg_setup() {
	[[ ${MERGE_TYPE} != binary ]] && use openmp && tc-check-openmp
}

src_prepare() {
	# cuda.eclass exports a src_prepare that dies without the toolkit.
	use cuda && cuda_src_prepare
	# Local CUDA speed-ups, A/B-tested at -ub 1024 against the unpatched
	# engine: flat Escha GEMV for narrow projections, packed FA columns,
	# chunked CUDA graph capture (upstream #30804) and the block-quantised
	# K/V element count (upstream #30541). The sources are CRLF; so is
	# the patch. eapply does not read .xz.
	xz -dc "${FILESDIR}/${P}-kfast.patch.xz" > "${T}/${P}-kfast.patch" || die
	eapply "${T}/${P}-kfast.patch"
	cmake_src_prepare
}

src_configure() {
	# cmake.eclass blanks the RelWithDebInfo flags, so -DNDEBUG is lost
	# and plain assert() stays live, which upstream never ships.
	if ! use debug; then
		append-cflags "-DNDEBUG"
		append-cxxflags "-DNDEBUG"
	fi

	local mycmakeargs=(
		# Binaries share names with sci-misc/llama-cpp: the whole fork
		# lives in /opt with prefixed symlinks (see src_install). Shared
		# libraries, since static linking copies the CUDA kernels into
		# every binary.
		-DCMAKE_INSTALL_PREFIX="${EPREFIX}/opt/${PN}"
		-DBUILD_SHARED_LIBS=ON
		-DCMAKE_INSTALL_LIBDIR="${EPREFIX}/opt/${PN}/lib"
		-DCMAKE_INSTALL_RPATH="${EPREFIX}/opt/${PN}/lib"
		-DCMAKE_SKIP_BUILD_RPATH=ON
		-DLLAMA_BUILD_TESTS=OFF
		-DLLAMA_BUILD_EXAMPLES=OFF
		-DLLAMA_BUILD_SERVER=ON
		# The unified "llama" binary carries a self-updater that pipes a
		# remote script into sh.
		-DLLAMA_BUILD_APP=OFF
		# The API server is all that is wanted; the UI options reach for
		# npm or a Hugging Face bucket.
		-DLLAMA_BUILD_UI=OFF
		-DLLAMA_USE_PREBUILT_UI=OFF
		-DLLAMA_OPENSSL=$(usex openssl)
		-DGGML_NATIVE=OFF	# don't set march
		-DGGML_CCACHE=OFF
		-DGGML_CUDA=$(usex cuda)
		-DGGML_CUDA_NCCL=OFF
		-DGGML_CUDA_GRAPHS=$(usex cuda)
		# Upstream's release builds leave the Mirai S kernels out; the
		# loader then refuses such files with a clear message.
		-DGGML_CUDA_MIRAI=OFF
		-DGGML_OPENMP=$(usex openmp)
		-DGGML_SSE42=$(usex cpu_flags_x86_sse4_2)
		-DGGML_AVX=$(usex cpu_flags_x86_avx)
		-DGGML_AVX_VNNI=$(usex cpu_flags_x86_avx_vnni)
		-DGGML_AVX2=$(usex cpu_flags_x86_avx2)
		-DGGML_BMI2=$(usex cpu_flags_x86_bmi2)
		-DGGML_F16C=$(usex cpu_flags_x86_f16c)
		-DGGML_FMA=$(usex cpu_flags_x86_fma3)
		-DGGML_AVX512=$(usex cpu_flags_x86_avx512f)
		-DGGML_AVX512_VBMI=$(usex cpu_flags_x86_avx512vbmi)
		-DGGML_AVX512_VNNI=$(usex cpu_flags_x86_avx512_vnni)
		-DGGML_AVX512_BF16=$(usex cpu_flags_x86_avx512_bf16)
	)

	if use cuda; then
		local -x CUDAHOSTCXX="$(cuda_gccdir)/g++"
		# Upstream releases build sm_75/86/89 only; CUDAARCHS from
		# make.conf wins, otherwise build for the local card.
		mycmakeargs+=( -DCMAKE_CUDA_ARCHITECTURES="${CUDAARCHS:-native}" )
		# nvcc recreates device symlinks during detection.
		cuda_add_sandbox
		addpredict "/dev/char/"
	fi

	cmake_src_configure
}

src_install() {
	cmake_src_install

	# Nothing links against the fork: drop what would advertise /opt.
	rm -rf "${ED}/opt/${PN}/include" "${ED}/opt/${PN}/lib"/{cmake,pkgconfig} || die
	# The converters need numpy and gguf-py; sci-misc/llama-cpp has them.
	rm -f "${ED}/opt/${PN}/bin"/*.py || die

	local b n
	for b in "${ED}/opt/${PN}/bin"/*; do
		n=${b##*/}
		dosym -r "/opt/${PN}/bin/${n}" "/usr/bin/kintsugi-${n}"
	done

	dodoc README.md docs/speculative.md
	newdoc ggml/src/ggml-cuda/exl3/LICENSE LICENSE.exl3
}

pkg_postinst() {
	elog "Binaries are in /opt/${PN}/bin, symlinked as kintsugi-llama-server"
	elog "and so on. The model and the optional DFlash2 drafter come from"
	elog "  https://huggingface.co/CaryPalmer/Kintsugi-27B"
	elog "Drafting is off unless asked for:"
	elog "  --spec-type draft-dflash -md dflash-Qwen3.8-27B-Q4_0.gguf --spec-draft-n-max 7"
	elog "or, without the drafter file,"
	elog "  --spec-type ngram-mod,draft-mtp --spec-draft-n-max 3"
	elog "The local speed patch was validated at -ub 1024; -ub 2048 changes"
	elog "answers on long prompts, with or without the patch."
	elog "Upstream measures RTX 20/30/40 cards; other generations build with"
	elog "CUDAARCHS set but are not covered by its tests."
}
