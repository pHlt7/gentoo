# Copyright 2025 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

DISTUTILS_USE_PEP517=setuptools
PYTHON_COMPAT=( python3_{11..13} )

inherit distutils-r1 optfeature pypi

DESCRIPTION="asyncio nostr client for Python"
HOMEPAGE="
	https://pypi.org/project/electrum-aionostr/
	https://github.com/spesmilo/electrum-aionostr
"

LICENSE="BSD"
SLOT="0"
KEYWORDS="~amd64"

RDEPEND="
	>=dev-python/aiohttp-3.11.0[${PYTHON_USEDEP}]
	>=dev-python/aiohttp-socks-0.9.2[${PYTHON_USEDEP}]
	>=dev-python/aiorpcx-0.22.0[${PYTHON_USEDEP}]
	<dev-python/aiorpcx-0.26[${PYTHON_USEDEP}]
	dev-python/cryptography[${PYTHON_USEDEP}]
	dev-python/electrum-ecc[schnorr,${PYTHON_USEDEP}]
"
BDEPEND="test? ( >=dev-python/click-8.2[${PYTHON_USEDEP}] )"

EPYTEST_PLUGINS=()
distutils_enable_tests pytest

pkg_postinst() {
	optfeature "command line interface" >=dev-python/click-8.2
	optfeature "faster asyncio event loop in CLI" dev-python/uvloop
}
