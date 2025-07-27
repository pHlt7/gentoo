# Copyright 2025 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

DISTUTILS_USE_PEP517=setuptools
PYTHON_COMPAT=( pypy3 python3_{11..14} )

inherit distutils-r1 pypi

DESCRIPTION="Library to communicate with Ledger Nano S/X and Speculos"
HOMEPAGE="
	https://pypi.org/project/ledgercomm/
	https://github.com/LedgerHQ/ledgercomm
"

LICENSE="MIT"
SLOT="0"
KEYWORDS="~amd64"
IUSE="hid"

# This package has no runtime tests
RESTRICT="test"

RDEPEND="hid? ( dev-python/hidapi[${PYTHON_USEDEP}] )"

python_prepare_all() {
	if ! use hid; then
		# prevent automagic dependency
		sed -i 's/import hid/raise ImportError/' \
		ledgercomm/interfaces/hid_device.py || die
	fi
	distutils-r1_python_prepare_all
}

python_install_all() {
	local -x DOCS=( CHANGELOG.md README.md )
	distutils-r1_python_install_all
}
