# Copyright 1999-2025 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

DISTUTILS_USE_PEP517=setuptools
PYTHON_COMPAT=( python3_{11..13} )
PYTHON_REQ_USE="ncurses?"

inherit distutils-r1 eapi9-ver optfeature verify-sig xdg-utils

MY_P=${P^}
DESCRIPTION="User friendly Bitcoin client"
HOMEPAGE="
	https://electrum.org/
	https://github.com/spesmilo/electrum/
"
SRC_URI="
	https://download.electrum.org/${PV}/${MY_P}.tar.gz
	verify-sig? (
		https://download.electrum.org/${PV}/${MY_P}.tar.gz.asc
	)
"
S=${WORKDIR}/${MY_P}

LICENSE="MIT"
SLOT="0"
KEYWORDS="~amd64"
IUSE="ncurses qrcode +qt6"

RDEPEND="
	${PYTHON_DEPS}
	>=dev-python/aiohttp-3.3.0[${PYTHON_USEDEP}]
	>=dev-python/aiohttp-socks-0.9.2[${PYTHON_USEDEP}]
	=dev-python/aiorpcx-0.25*[${PYTHON_USEDEP}]
	>=dev-python/attrs-20.1.0[${PYTHON_USEDEP}]
	dev-python/certifi[${PYTHON_USEDEP}]
	>=dev-python/dnspython-2.2[dnssec,${PYTHON_USEDEP}]
	>=dev-python/electrum-aionostr-0.0.11[${PYTHON_USEDEP}]
	>=dev-python/electrum-ecc-0.0.4[schnorr,${PYTHON_USEDEP}]
	dev-python/jsonpatch[${PYTHON_USEDEP}]
	dev-python/jsonpointer[${PYTHON_USEDEP}]
	>=dev-python/protobuf-3.20[${PYTHON_USEDEP}]
	dev-python/qrcode[${PYTHON_USEDEP}]
	x11-themes/hicolor-icon-theme
	|| (
		dev-python/cryptography[${PYTHON_USEDEP}]
		dev-python/pycryptodome[${PYTHON_USEDEP}]
	)
	ncurses? (
		$(python_gen_impl_dep 'ncurses')
		dev-python/pyperclip[${PYTHON_USEDEP}]
	)
	qrcode? ( media-gfx/zbar[v4l] )
	qt6? (
		dev-python/pyqt6[gui,widgets,${PYTHON_USEDEP}]
	)
"
BDEPEND="
	test? (
		dev-python/cryptography[${PYTHON_USEDEP}]
		dev-python/pyaes[${PYTHON_USEDEP}]
		dev-python/pycryptodome[${PYTHON_USEDEP}]
	)
	verify-sig? (
		sec-keys/openpgp-keys-electrum
	)
"

EPYTEST_PLUGINS=()
distutils_enable_tests pytest

EPYTEST_IGNORE=(
	# test for qml/PyQt6 GUI that doesn't work anyway
	tests/test_qml_types.py
)

VERIFY_SIG_OPENPGP_KEY_PATH=/usr/share/openpgp-keys/electrum.asc

src_prepare() {
	distutils-r1_src_prepare

	# remove bundled dependencies
	rm -r packages || die

	# use backwards-compatible cryptodome API
	# don't try to import fallback crypto backend
	sed -i -e 's:Cryptodome:Crypto:' \
		-e 's:import pyaes:raise ImportError():' electrum/crypto.py || die

	local bestgui
	if use qt6; then
		bestgui=qt
	elif use ncurses; then
		bestgui=text
	else
		bestgui=stdio
	fi
	sed -i 's/^\([[:space:]]*\)\(config_options\['\''cwd'\''\] = .*\)$/\1\2\n\1config_options.setdefault("gui", "'"${bestgui}"'")\n/' ${PN}/${PN} || die
}

src_install() {
	dodoc RELEASE-NOTES
	distutils-r1_src_install
}

pkg_postinst() {
	xdg_icon_cache_update
	xdg_desktop_database_update

	optfeature "dark mode in GUI" dev-python/qdarkstyle

	ver_replacing -ge 4.3.4 && return

	ewarn "If you are new to BitCoin, please be aware that:"
	ewarn "1. Cryptocurrencies are volatile.  BTC has been subject to rapid"
	ewarn "   changes of value in the past."
	ewarn "2. Cryptocurrency ownership is determined solely by the access to"
	ewarn "   the private key.  If the key is lost or stolen, BTC are unrevocably"
	ewarn "   lost."
	ewarn "3. Proof-of-work based cryptocurrencies have negative environmental"
	ewarn "   impact.  BTC mining is consuming huge amounts of electricity."
}

pkg_postrm() {
	xdg_icon_cache_update
	xdg_desktop_database_update
}
