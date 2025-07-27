# Copyright 2025 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

DISTUTILS_USE_PEP517=setuptools
PYTHON_COMPAT=( python3_{11..14} )

inherit distutils-r1 pypi

DESCRIPTION="Pure Python interface to libsecp256k1 using ctypes"
HOMEPAGE="
	https://pypi.org/project/electrum-ecc/
	https://github.com/spesmilo/electrum-ecc
"

LICENSE="MIT"
SLOT="0"
KEYWORDS="~amd64"
IUSE="+schnorr"

# check KNOWN_COMPATIBLE_ABI_VERSIONS in
# electrum_ecc/ecc_fast.py when updating RDEPEND

RDEPEND="<dev-libs/libsecp256k1-0.7.0[recovery,schnorr?]"
BDEPEND="test? ( dev-libs/libsecp256k1[schnorr] )"

distutils_enable_tests unittest

python_compile() {
	local -x ELECTRUM_ECC_DONT_COMPILE=1
	distutils-r1_python_compile
}

python_test() {
	cd tests || die
	eunittest
}
