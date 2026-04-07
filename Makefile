SHELL := /bin/bash
.ONESHELL:
.SHELLFLAGS := -euo pipefail -c

# =============================================================================
# Base tools — shared by all projects
# =============================================================================
# NOTE: System packages installed via apt-get are not version-pinned.
# apt-get update pulls the latest package list, so versions may differ
# depending on when the container is built. This affects: curl, wget,
# git, jq, make, python3-pip, vim, neovim, openssh-client, build-essential,
# and pyenv/goenv build dependencies (libssl-dev, etc.).
# Pinned tools (Go, Python, cocotb, oss-cad-suite) are not affected.
TOOLS:
	apt-get update -qq
	apt-get install -y -qq \
		vim neovim openssh-client \
		curl wget git jq make python3-pip \
		build-essential \
		libssl-dev zlib1g-dev libbz2-dev libreadline-dev \
		libsqlite3-dev libffi-dev liblzma-dev
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
