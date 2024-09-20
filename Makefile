ARCH    ?= $(shell arch)
CONFIG  ?= release
TRIPLE  ?= $(ARCH)-apple-macosx
NAME    ?= neovide-start
BINDIR  ?= $(HOME)/bin

all:
	swift build -c $(CONFIG)

install:
	@install  -m 0555 -C -p -S -U -v      \
	  .build/$(TRIPLE)/$(CONFIG)/$(NAME)  \
	  $(BINDIR)

clean:
	rm -rf .build
