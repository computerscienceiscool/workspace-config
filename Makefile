SHELL := /bin/bash
.ONESHELL:
.SHELLFLAGS := -euo pipefail -c

# =============================================================================
# Ordering — this is the whole point of the file
# =============================================================================
# Every install is a target. Every target touches a stamp on success.
# decomk runs make in /var/decomk/stamps, so `touch $@` lands there.
# Re-runs see the stamp and skip. That is how a Makefile run at image-build
# time AND again at container-create time stays a no-op the second pass.
#
# Dependency chain (left = runs first, right = runs last):
#
#   block00  ->  TOOLS  ->  GO   ->  (Go-dependent targets)
#                       ->  PYTHON -> COCOTB
#                                  -> (other Python targets)
#
# Block composition (each block is a cumulative snapshot):
#
#   block00  = (empty here; content is in workspace-base Dockerfile's
#              block00 region: Microsoft base + decomk binary only)
#   block0   = block00 + TOOLS + GO + PYTHON   <-- gold image payload
#   block10  = block0  + (next shared additions as prereqs)
#
# DEFAULT is an alias for block0, preserved so existing decomk.conf
# entries (e.g. `fpga-workbench: DEFAULT FPGA`) continue to resolve.
#
# Rule: new shared tools go in as prereqs of the next block number.
#       project-specific tools never go in a block; they go in
#       project macros (see FPGA) and hang off `DEFAULT` via decomk.conf.
# =============================================================================

block00:
	touch $@

block0: block00 TOOLS GO PYTHON
	touch $@

block10: block0
	touch $@

DEFAULT: block0
	touch $@

# =============================================================================
# Base tools — shared by all projects
# =============================================================================
# Versions pinned to Ubuntu 24.04 (noble) as of the base image
# mcr.microsoft.com/devcontainers/base:ubuntu. Update when the base
# image is re-pinned.
TOOLS:
	apt-get update -qq
	apt-get install -y -qq \
		vim=2:9.1.0016-1ubuntu7.11 \
		neovim=0.9.5-6ubuntu2 \
		openssh-client=1:9.6p1-3ubuntu13.15 \
		curl=8.5.0-2ubuntu10.8 \
		wget=1.21.4-1ubuntu4.1 \
		git=1:2.43.0-1ubuntu7.3 \
		jq=1.7.1-3ubuntu0.24.04.1 \
		make=4.3-4.1build2 \
		python3-pip=24.0+dfsg-1ubuntu1.3 \
		build-essential=12.10ubuntu1 \
		libssl-dev=3.0.13-0ubuntu3.9 \
		zlib1g-dev=1:1.3.dfsg-3.1ubuntu2.1 \
		libbz2-dev=1.0.8-5.1build0.1 \
		libreadline-dev=8.2-4build1 \
		libsqlite3-dev=3.45.1-1ubuntu2.5 \
		libffi-dev=3.4.6-1build1 \
		liblzma-dev=5.6.1+really5.4.5-1ubuntu0.2
	# --- goenv ---
	if [ ! -d "/usr/local/goenv" ]; then \
		git clone https://github.com/go-nv/goenv.git /usr/local/goenv; \
	fi
	echo 'export GOENV_ROOT="/usr/local/goenv"' > /etc/profile.d/goenv.sh
	echo 'export PATH="$$GOENV_ROOT/bin:$$GOENV_ROOT/shims:$$PATH"' >> /etc/profile.d/goenv.sh
	# --- pyenv ---
	if [ ! -d "/usr/local/pyenv" ]; then \
		git clone https://github.com/pyenv/pyenv.git /usr/local/pyenv; \
	fi
	echo 'export PYENV_ROOT="/usr/local/pyenv"' > /etc/profile.d/pyenv.sh
	echo 'export PATH="$$PYENV_ROOT/bin:$$PYENV_ROOT/shims:$$PATH"' >> /etc/profile.d/pyenv.sh
	touch $@

# =============================================================================
# Language versions — pinned for reproducibility
# =============================================================================

GO: TOOLS
	export GOENV_ROOT="/usr/local/goenv"
	export PATH="$$GOENV_ROOT/bin:$$GOENV_ROOT/shims:$$PATH"
	if goenv versions --bare | grep -q "^1\.24\.13$$"; then \
		echo "Go 1.24.13 already installed, skipping"; \
	else \
		goenv install 1.24.13; \
	fi
	goenv global 1.24.13
	touch $@

PYTHON: TOOLS
	export PYENV_ROOT="/usr/local/pyenv"
	export PATH="$$PYENV_ROOT/bin:$$PYENV_ROOT/shims:$$PATH"
	if pyenv versions --bare | grep -q "^3\.12$$"; then \
		echo "Python 3.12 already installed, skipping"; \
	else \
		pyenv install 3.12; \
	fi
	pyenv global 3.12
	touch $@

# =============================================================================
# FPGA targets — used by fpga-workbench and similar projects
# =============================================================================

OSS: TOOLS
	if [ -x "/opt/oss-cad-suite/bin/iverilog" ]; then \
		echo "oss-cad-suite already installed, skipping"; \
	else \
		wget -q "https://github.com/YosysHQ/oss-cad-suite-build/releases/download/2026-03-07/oss-cad-suite-linux-x64-20260307.tgz" -O /tmp/oss-cad-suite.tgz; \
		mkdir -p /opt; \
		tar xzf /tmp/oss-cad-suite.tgz -C /opt; \
		rm -f /tmp/oss-cad-suite.tgz; \
	fi
	echo 'export PATH="/opt/oss-cad-suite/bin:$$PATH"' > /etc/profile.d/oss-cad-suite.sh
	touch $@

I2C: TOOLS
	if [ ! -d "/workspaces/i2cslave" ]; then \
		GIT_TERMINAL_PROMPT=0 git clone https://github.com/AdrianSuliga/I2C-Slave-Controller.git /workspaces/i2cslave 2>/dev/null || \
			echo "WARNING: Could not clone I2C reference"; \
	fi
	touch $@

COCOTB: PYTHON
	export PYENV_ROOT="/usr/local/pyenv"
	export PATH="$$PYENV_ROOT/bin:$$PYENV_ROOT/shims:$$PATH"
	if python3 -c "import cocotb" >/dev/null 2>&1; then \
		echo "cocotb already installed, skipping"; \
	else \
		pip install cocotb==2.0.1 cocotb-bus==0.3.0; \
	fi
	touch $@
