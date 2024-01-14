VESC_TOOL ?= vesc_tool

all: refloat.vescpkg

refloat.vescpkg: refloat refloat.lisp README-pkg.md ui.qml
	$(VESC_TOOL) --buildPkg "refloat.vescpkg:refloat.lisp:ui.qml:0:README-pkg.md:Refloat"

refloat:
	$(MAKE) -C $@

VERSION=`cat version`

README-pkg.md: README.md version
	cp $< $@
	echo "- Version: ${VERSION}" >> $@
	echo "- Build Date: `date --rfc-3339=seconds`" >> $@
	echo "- Git Commit: #`git rev-parse --short HEAD`" >> $@

ui.qml: ui.qml.in version
	cat $< | sed "s/{{VERSION}}/${VERSION}/g" > $@

clean:
	rm -f refloat.vescpkg README-pkg.md ui.qml
	$(MAKE) -C refloat clean

.PHONY: all clean refloat
