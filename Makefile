HSHOME = $$HOME/.hammerspoon

all:
	@echo "Run 'make install' to install via default method (currently copy)."
	@echo "Run 'make copy' to install via copy."
	@echo "Run 'make link' to install via hard-link (falls back to copy)."
	@echo "Run 'make symlink' to install via symlink (will not auto-reload on change with pathwatcher)."
	@echo
	@echo 'Hammerspoon directory: $(HSHOME)'
	@echo "Override with 'HSHOME=/path/to/.hammerspoon' on the 'make' command line."

SOURCES := sshchooser.lua

install: copy

# TODO This is broken in that hammerspoon will not notice changes to this file
# automatically. Pathwatcher doesn't watch for changes to the target of
# symlinks.
.PHONY: symlink
symlink: $(SOURCES)
	@ln -v -s '$(abspath $^)' "$(HSHOME)/"

.PHONY: link
link: $(SOURCES)
	@ln -v '$(abspath $^)' "$(HSHOME)/" || $(MAKE) copy

.PHONY: copy
copy: $(SOURCES)
	@install -C -S -v '$^' "$(HSHOME)/"

.SUFFIXES:
MAKEFLAGS += -rR
