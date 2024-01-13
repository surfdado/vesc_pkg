VESC_TOOL ?= vesc_tool

all: refloat.vescpkg

refloat.vescpkg: refloat refloat.lisp README-pkg.md ui.qml
	$(VESC_TOOL) --buildPkg "refloat.vescpkg:refloat.lisp:ui.qml:0:README-pkg.md:Refloat"

refloat:
	$(MAKE) -C $@

VERSION=`grep CFG_DFLT_VERSION refloat/conf/settings.xml -A10 | grep valDouble | tr -dc '[.[:digit:]]'`

README-pkg.md: README.md
	cp README.md README-pkg.md
	echo "- Version: ${VERSION}" >> README-pkg.md
	echo "- Build Date: `date --rfc-3339=seconds`" >> README-pkg.md
	echo "- Git Commit: #`git rev-parse --short HEAD`" >> README-pkg.md

ui.qml: ui.qml.in
	cat ui.qml.in | sed "s/{{VERSION}}/${VERSION}/g" > ui.qml

clean:
	rm -f refloat.vescpkg README-pkg.md ui.qml
	$(MAKE) -C refloat clean

.PHONY: all clean refloat
