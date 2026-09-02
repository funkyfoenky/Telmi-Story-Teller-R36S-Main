# Telmi-os — storyTeller / bootScreen / batmon (glibc aarch64, blit fb0).
# Usage plus tard : make -C telmi-os/src CC=aarch64-linux-gnu-gcc

ROOT := $(patsubst %/,%,$(dir $(lastword $(MAKEFILE_LIST))))
include $(ROOT)/config.mk

STAGING ?= $(ROOT)/../../staging/opt/telmi/bin
VENDOR := $(ROOT)/vendor

CFLAGS += -DSOYSAUCE_FB_PRESENT \
	-I$(ROOT) \
	-I$(ROOT)/storyTeller \
	-I$(VENDOR)/src/storyTeller \
	-I$(VENDOR)/include \
	-I$(VENDOR)/src/common \
	-I$(VENDOR)/src/common/utils \
	$(EXTRA_CFLAGS)
LDFLAGS += $(EXTRA_LDFLAGS)

COMMON_UTILS := $(VENDOR)/src/common/utils/str.c \
	$(VENDOR)/src/common/utils/log.c \
	$(VENDOR)/src/common/utils/file.c

.PHONY: all clean dirs storyTeller bootScreen batmon

all: dirs bootScreen storyTeller batmon

dirs:
	@mkdir -p $(STAGING)

bootScreen: $(ROOT)/bootScreen.c $(COMMON_UTILS)
	$(CC) $(CFLAGS) -o $(STAGING)/bootScreen $^ $(EXTRA_LDFLAGS) -lpng -lz -lpthread -lm
	$(STRIP) $(STAGING)/bootScreen

storyTeller: dirs $(ROOT)/storyTeller/storyTeller.c \
	$(VENDOR)/include/cjson/cJSON.c \
	$(COMMON_UTILS) $(ROOT)/mixer_compat.c
	$(CC) $(CFLAGS) \
		-o $(STAGING)/storyTeller \
		$(ROOT)/storyTeller/storyTeller.c \
		$(VENDOR)/include/cjson/cJSON.c \
		$(COMMON_UTILS) $(ROOT)/mixer_compat.c \
		$(LDFLAGS)
	$(STRIP) $(STAGING)/storyTeller

batmon: $(ROOT)/batmon_simple.c
	$(CC) $(CFLAGS) -o $(STAGING)/batmon $(ROOT)/batmon_simple.c
	$(STRIP) $(STAGING)/batmon

clean:
	rm -f $(STAGING)/bootScreen $(STAGING)/storyTeller $(STAGING)/batmon
