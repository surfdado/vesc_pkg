VESC_TOOL ?= vesc_tool

TARGET = refloat

SOURCES = main.c conf/buffer.c conf/confparser.c conf/confxml.c

ADD_TO_CLEAN = conf/conf_default.h conf/confparser.c conf/confparser.h conf/confxml.c conf/confxml.h

VESC_C_LIB_PATH = ../../c_libs/
include $(VESC_C_LIB_PATH)rules.mk

main.c: conf/confparser.h conf/confxml.h

conf/conf_default.h conf/confparser.c conf/confparser.h conf/confxml.c conf/confxml.h &: conf/settings.xml
	$(VESC_TOOL) --xmlConfToCode conf/settings.xml
