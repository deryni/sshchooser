HSHOME = $$HOME/.hammerspoon

all:
	@echo "Run 'make install' to install (via default method)."
	@echo "Run 'make copy' to install via copy."
	@echo "Run 'make install' to install via symlink (will not auto-reload on change with pathwatcher)."
	@echo
	@echo 'Hammerspoon directory: $(HSHOME)'
	@echo "Override with 'HSHOME=/path/to/.hammerspoon' on the 'make' command line."

SOURCES := sshchooser.lua

install: copy

# TODO This is broken in that hammerspoon will not notice changes to this file
# automatically.
.PHONY: symlink
symlink: $(SOURCES)
	@ln -v -s '$^' '$(HSHOME)/'

.PHONY: copy
copy: $(SOURCES)
	@cp -v '$^' '$(HSHOME)/'

.SUFFIXES:
MAKEFLAGS += -rR
