# Copyright 2010-2025 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI="8"

PYTHON_COMPAT=( python3_{11..14} )

inherit desktop elisp-common python-any-r1 savedconfig xdg

if [[ "${PV}" == "9999" ]]; then
	inherit git-r3
fi

DESCRIPTION="Mozc - Japanese input method editor"
HOMEPAGE="https://github.com/google/mozc"
if [[ "${PV}" == "9999" ]]; then
	EGIT_REPO_URI="https://github.com/google/mozc"
	EGIT_SUBMODULES=(src/third_party/japanese_usage_dictionary)
else
	FCITX_MOZC_GIT_REVISION="a6b57d8e5de15fc34df6e22927dcd0a00ca46641"
	JAPANESE_USAGE_DICTIONARY_GIT_REVISION="38d34621238afe66e8e669ff0a37bc84039b6b93"
	SRC_URI="
		https://github.com/google/mozc/archive/refs/tags/${PV}.tar.gz -> ${P}.gh.tar.gz
		https://github.com/hiroyuki-komatsu/japanese-usage-dictionary/archive/${JAPANESE_USAGE_DICTIONARY_GIT_REVISION}.tar.gz
		-> japanese-usage-dictionary-${JAPANESE_USAGE_DICTIONARY_GIT_REVISION}.tar.gz
		fcitx5? (
		https://github.com/fcitx/mozc/archive/${FCITX_MOZC_GIT_REVISION}.tar.gz
		-> fcitx-mozc-${FCITX_MOZC_GIT_REVISION}.gh.tar.gz
		)
	"
	SRC_URI+="
		https://github.com/bazelbuild/bazel/releases/download/8.1.1/bazel-8.1.1-linux-x86_64
	"
fi
S="${WORKDIR}/${P}/src"

# https://dev.gentoo.org/~sam/distfiles/${CATEGORY}/${PN}/${PN}-2.28.5029.102-patches.tar.xz

# Mozc: BSD
# src/data/dictionary_oss: ipadic, public-domain
# src/data/unicode: unicode
# japanese-usage-dictionary: BSD-2
LICENSE="BSD BSD-2 ipadic public-domain unicode"
SLOT="0"
KEYWORDS="~amd64 ~arm64 ~loong ~x86"
IUSE="debug emacs +fcitx5 +gui ibus renderer test"
REQUIRED_USE="|| ( emacs fcitx5 ibus )"

RESTRICT="!test? ( test )"

BDEPEND="
	app-alternatives/ninja
	>=dev-libs/protobuf-3.0.0
	$(python_gen_any_dep 'dev-python/six[${PYTHON_USEDEP}]')
	virtual/pkgconfig
	emacs? ( app-editors/emacs:* )
	fcitx5? ( sys-devel/gettext )
	test? (
		>=dev-cpp/gtest-1.8.0
		dev-libs/jsoncpp
	)
"
DEPEND="
	>=dev-cpp/abseil-cpp-20250512.0:=
	>=dev-libs/protobuf-3.0.0:=
	fcitx5? (
		app-i18n/fcitx:5
		app-i18n/libime
		sys-devel/gettext
		virtual/libintl
	)
	gui? (
		 dev-qt/qtbase:6[gui,widgets]
	)
	ibus? (
		>=app-i18n/ibus-1.4.1
		dev-libs/glib:2
		x11-libs/libxcb
	)
	renderer? (
		dev-libs/glib:2
		x11-libs/cairo
		x11-libs/gtk+:2
		x11-libs/pango
	)
"
RDEPEND="
	${DEPEND}
	>=dev-cpp/abseil-cpp-20230802.0:=[cxx17(+)]
	emacs? ( app-editors/emacs:* )
"

SITEFILE="50${PN}-gentoo.el"

python_check_deps() {
	python_has_version "dev-python/six[${PYTHON_USEDEP}]"
}

src_unpack() {
	if [[ "${PV}" == "9999" ]]; then
		git-r3_src_unpack

		if use fcitx5; then
			local EGIT_SUBMODULES=()
			git-r3_fetch https://github.com/fcitx/mozc refs/heads/fcitx
			git-r3_checkout https://github.com/fcitx/mozc "${WORKDIR}/fcitx-mozc"
			cp -pr "${WORKDIR}"/fcitx{,5}-mozc || die
		fi
	else
		default
		cp -p japanese-usage-dictionary-${JAPANESE_USAGE_DICTIONARY_GIT_REVISION}/usage_dict.txt \
		   ${P}/src/third_party/japanese_usage_dictionary || die
	fi
}

src_prepare() {
	if use fcitx5; then
		cp -pr "${WORKDIR}/mozc-${FCITX_MOZC_GIT_REVISION}/src/unix/fcitx5" unix || die
	fi

	pushd "${WORKDIR}/${P}" > /dev/null || die
	default
	popd > /dev/null || die

	# bug #877765
	restore_config mozcdic-ut.txt
	if [[ -f mozcdic-ut.txt && -s mozcdic-ut.txt ]]; then
		einfo "mozcdic-ut.txt found. Adding to mozc dictionary..."
		cat mozcdic-ut.txt >> "${WORKDIR}/${P}/src/data/dictionary_oss/dictionary00.txt" || die
	fi
}

ebazel() {
	if [[ ! -x "${T}"/bazel ]]; then
		cp "${DISTDIR}"/bazel-8.1.1-linux-x86_64 "${T}"/bazel || die
		chmod +x "${T}"/bazel || die
	fi
	set -- bazel "$@"
	einfo "${@}"
	"${T}"/"${@}" || die
}

src_compile() {
	if use emacs; then
		elisp-compile unix/emacs/*.el
	fi
	ebazel build package --config oss_linux --config release_build
}

src_install() {
	exeinto /usr/libexec/mozc
	doexe out_linux/${BUILD_TYPE}/mozc_server

	[[ -s mozcdic-ut.txt ]] && save_config mozcdic-ut.txt

	if use gui; then
		doexe out_linux/${BUILD_TYPE}/mozc_tool
	fi

	if use renderer; then
		doexe out_linux/${BUILD_TYPE}/mozc_renderer
	fi

	insinto /usr/libexec/mozc/documents
	doins data/installer/credits_en.html

	if use emacs; then
		dobin out_linux/${BUILD_TYPE}/mozc_emacs_helper
		elisp-install ${PN} unix/emacs/*.{el,elc}
		elisp-site-file-install "${FILESDIR}/${SITEFILE}" ${PN}
	fi

	if use fcitx5; then
		exeinto /usr/$(get_libdir)/fcitx5
		doexe out_linux/${BUILD_TYPE}/fcitx5-mozc.so

		insinto /usr/share/fcitx5/addon
		newins unix/fcitx5/mozc-addon.conf mozc.conf

		insinto /usr/share/fcitx5/inputmethod
		doins unix/fcitx5/mozc.conf

		local orgfcitx5="org.fcitx.Fcitx5.fcitx-mozc"
		newicon -s 128 data/images/product_icon_32bpp-128.png ${orgfcitx5}.png
		newicon -s 128 data/images/product_icon_32bpp-128.png fcitx-mozc.png
		newicon -s 32 data/images/unix/ime_product_icon_opensource-32.png ${orgfcitx5}.png
		newicon -s 32 data/images/unix/ime_product_icon_opensource-32.png fcitx-mozc.png
		for uiimg in ../../fcitx5-mozc/scripts/icons/ui-*.png; do
			dimg=${uiimg#*ui-}
			newicon -s 48 ${uiimg} ${orgfcitx5}-${dimg/_/-}
			newicon -s 48 ${uiimg} fcitx-mozc-${dimg/_/-}
		done

		local locale mo_file
		for mo_file in unix/fcitx5/po/*.po; do
			locale="${mo_file##*/}"
			locale="${locale%.po}"
			msgfmt ${mo_file} -o ${mo_file/.po/.mo} || die
			insinto /usr/share/locale/${locale}/LC_MESSAGES
			newins "${mo_file/.po/.mo}" fcitx5-mozc.mo
		done
		msgfmt --xml -d unix/fcitx5/po/ --template unix/fcitx5/org.fcitx.Fcitx5.Addon.Mozc.metainfo.xml.in -o \
			unix/fcitx5/org.fcitx.Fcitx5.Addon.Mozc.metainfo.xml || die
		insinto /usr/share/metainfo
		doins unix/fcitx5/org.fcitx.Fcitx5.Addon.Mozc.metainfo.xml
	fi

	if use ibus; then
		exeinto /usr/libexec
		newexe out_linux/${BUILD_TYPE}/ibus_mozc ibus-engine-mozc

		insinto /usr/share/ibus/component
		doins out_linux/${BUILD_TYPE}/gen/unix/ibus/mozc.xml

		insinto /usr/share/ibus-mozc
		newins data/images/unix/ime_product_icon_opensource-32.png product_icon.png
		local image
		for image in data/images/unix/ui-*.png; do
			newins "${image}" "${image#data/images/unix/ui-}"
		done
	fi
}

pkg_postinst() {
	elog
	elog "ENVIRONMENTAL VARIABLES"
	elog
	elog "MOZC_SERVER_DIRECTORY"
	elog "  Mozc server directory"
	elog "  Value used by default: \"${EPREFIX}/usr/libexec/mozc\""
	elog "MOZC_DOCUMENTS_DIRECTORY"
	elog "  Mozc documents directory"
	elog "  Value used by default: \"${EPREFIX}/usr/libexec/mozc/documents\""
	elog "MOZC_CONFIGURATION_DIRECTORY"
	elog "  Mozc configuration directory"
	elog "  Value used by default: \"~/.mozc\""
	elog
	if use emacs; then
		elog
		elog "USAGE IN EMACS"
		elog
		elog "mozc-mode is minor mode to input Japanese text using Mozc server."
		elog "mozc-mode can be used via LEIM (Library of Emacs Input Method)."
		elog
		elog "In order to use mozc-mode by default, the following settings should be added to"
		elog "Emacs init file (~/.emacs.d/init.el or ~/.emacs):"
		elog
		elog "  (require 'mozc)"
		elog "  (set-language-environment \"Japanese\")"
		elog "  (setq default-input-method \"japanese-mozc\")"
		elog
		elog "With the above settings, typing C-\\ (which is bound to \"toggle-input-method\""
		elog "by default) will enable mozc-mode."
		elog
		elog "Alternatively, at run time, after loading mozc.el, mozc-mode can be activated by"
		elog "calling \"set-input-method\" and entering \"japanese-mozc\"."
		elog

		elisp-site-regen
	fi
	xdg_pkg_postinst
}

pkg_postrm() {
	if use emacs; then
		elisp-site-regen
	fi
	xdg_pkg_postrm
}
