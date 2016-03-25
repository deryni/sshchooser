HSHOME = $$HOME/.hammerspoon

all:
	@echo "Run 'make install' to install via symlink."
	@echo "Run 'make copy' to install via copy."
	@echo
	@echo 'Hammerspoon directory: $(HSHOME)'
	@echo "Override with 'HSHOME=/path/to/hammerspoon' on the 'make' command line."

.PHONY: install
install: sshchooser.lua
	@ln -v -s '$^' '$(HSHOME)/'

.PHONY: copy
copy: sshchooser.lua
	@cp -v '$^' '$(HSHOME)/'
