VESC_TOOL ?= vesc_tool

all: gosmilo.vescpkg

gosmilo.vescpkg: gosmilo README-pkg.md ui.qml
	$(VESC_TOOL) --buildPkg "gosmilo.vescpkg:gosmilo.lisp:ui.qml:0:README-pkg.md:GoSmilo"

gosmilo:
	$(MAKE) -C $@

VERSION=`grep APPCONF_FLOAT_VERSION gosmilo/conf/settings.xml -A10 | grep valDouble | tr -dc '[.[:digit:]]'`

README-pkg.md: README.md
	cp README.md README-pkg.md
	echo "- Version: ${VERSION}" >> README-pkg.md
	echo "- Build Date: `date --rfc-3339=seconds`" >> README-pkg.md
	echo "- Git Commit: #`git rev-parse --short HEAD`" >> README-pkg.md

ui.qml: ui.qml.in
	cat ui.qml.in | sed "s/{{VERSION}}/${VERSION}/g" > ui.qml

clean:
	rm -f gosmilo.vescpkg README-pkg.md ui.qml
	$(MAKE) -C gosmilo clean

.PHONY: all clean gosmilo
