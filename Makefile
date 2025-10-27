# Minimal Makefile for Nix and venv

SHELL			:= /bin/bash


export PYTHON		?= $(shell python3 --version >/dev/null 2>&1 && echo python3 || echo python )

# Ensure $(PYTHON), $(VENV) are re-evaluated at time of expansion, when target $(PYTHON) are known to be available
PYTHON_V		= $(shell $(PYTHON) -c "import sys; print('-'.join((('venv' if sys.prefix != sys.base_prefix else next(iter(filter(None,sys.base_prefix.split('/'))))),sys.platform,sys.implementation.cache_tag)))" 2>/dev/null )

export TOX		?= tox
export TOX_OPTS		?= -e py39-extra,py310-extra,py311-extra,py312-extra,py313-extra
#export TOX_OPTS		?= -e py311-extra,py312-extra,py313-extra
export PYTEST		?= $(PYTHON) -m pytest
export PYTEST_OPTS	?= # -vv --capture=no

VERSION			= $(shell $(PYTHON) -c "exec(open('tabulate/version.py').read()); print('.'.join(map(str, __version_tuple__[:3])))" )
VERSION_FULL		= $(shell $(PYTHON) -c "exec(open('tabulate/version.py').read()); print(__version__)" )
WHEEL			= dist/tabulate_slip39-$(VERSION_FULL)-py3-none-any.whl
VENV			= $(CURDIR)-$(VERSION)-$(PYTHON_V)

# Force export of variables that might be set from command line
export VENV_OPTS	?=
export NIX_OPTS		?=

# Put it first so that "make" without argument is like "make help".
help:
	@echo "Build and test tabulate under Nix and Python venv"
	@echo
	@echo "  nix-...   Make a target in the Nix Flake develop environment"
	@echo "  venv      Create and start a Python venv using the available Python interpreter"
	@echo "  venv-...  Make a target using the venv environment"
	@echo
	@echo "For example, to run tox tests in a Nix-supplied Python venv:"
	@echo
	@echo "  make nix-venv-test"
	@echo

.PHONY: help wheel install test bench analyze types venv Makefile FORCE

wheel:			$(WHEEL)

$(WHEEL):		FORCE
	$(PYTHON) -m build
	@ls -last dist

# Install from wheel, including all optional extra dependencies (doesn't include dev)
install:		$(WHEEL) FORCE
	$(PYTHON) -m pip install --force-reinstall $<

# Install from requirements/*; eg. install-dev, always getting the latest version
install-%:  		FORCE
	$(PYTHON) -m pip install --upgrade -r requirements/$*.txt


unit-%:
	$(PYTEST) $(PYTEST_OPTS) -k $*

test:
	$(TOX) $(TOX_OPTS)

lint:
	python -m pre_commit run -a

bench:
	$(PYTHON) benchmark/benchmark.py

analyze:
	$(PYTHON) -m flake8 --color never -j 1 --max-line-length=250 \
	  --ignore=W503,W504,E201,E202,E223,E226 \
	  tabulate

types:
	mypy .

#
# Nix and VirtualEnv build, install and activate
#
#     Create, start and run commands in "interactive" shell with a python venv's activate init-file.
# Doesn't allow recursive creation of a venv with a venv-supplied python.  Alters the bin/activate
# to include the user's .bashrc (eg. Git prompts, aliases, ...).  Use to run Makefile targets in a
# proper context, for example to obtain a Nix environment containing the proper Python version,
# create a python venv with the current Python environment.
#
#     make nix-venv-build
#
nix-%:
	@if [ -r flake.nix ]; then \
	    nix develop $(NIX_OPTS) --command make $*; \
        else \
	    nix-shell $(NIX_OPTS) --run "make $*"; \
	fi

venv-%:			$(VENV)
	@echo; echo "*** Running in $< VirtualEnv: make $*"
	@bash --init-file $</bin/activate -ic "make $*"

venv:			$(VENV)
	@echo; echo "*** Activating $< VirtualEnv for Interactive $(SHELL)"
	@bash --init-file $</bin/activate -i

$(VENV):
	@[[ "$(PYTHON_V)" =~ "^venv" ]] && ( echo -e "\n\n!!! $@ Cannot start a venv within a venv"; false ) || true
	@echo; echo "*** Building $@ VirtualEnv..."
	@rm -rf $@ && $(PYTHON) -m venv $(VENV_OPTS) $@ && sed -i -e '1s:^:. $$HOME/.bashrc\n:' $@/bin/activate \
	    && source $@/bin/activate \
	    && make install-dev install

print-%:
	@echo $* = $($*)
	@echo $*\'s origin is $(origin $*)

