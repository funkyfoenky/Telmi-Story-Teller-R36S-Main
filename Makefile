# Telmi-os 0.2.3 — image V30 + packs DTB ArkOS4Clone + Select-DTB.
SHELL := /bin/bash
ROOT := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))
SCRIPTS := $(ROOT)/scripts
VERSION := $(shell tr -d '[:space:]' < $(ROOT)/VERSION)

.PHONY: help all seed telmi assets rootfs image toolchain kernel dtb uboot

help:
	@echo "telmi-os $(VERSION)"
	@echo "  make image      bake output/soysauce-$(VERSION).img (root, prebuilts + debootstrap)"
	@echo "  make seed       copie vendor/prebuilt -> staging"
	@echo "  make telmi      recross-compile storyTeller (exige SYSROOT)"
	@echo "  make kernel     rebuild Image (exige ../third_party/linux)"
	@echo "  make dtb        compile dts/ v30"
	@echo "  make rootfs     debootstrap (root)"

all:
	bash $(SCRIPTS)/all.sh

seed:
	bash $(SCRIPTS)/seed-prebuilt.sh

toolchain:
	bash $(SCRIPTS)/setup-toolchain.sh

kernel:
	bash $(SCRIPTS)/build-kernel.sh

dtb:
	bash $(SCRIPTS)/build-dtb.sh

uboot:
	bash $(SCRIPTS)/build-uboot.sh

telmi:
	bash $(SCRIPTS)/build-telmi.sh

assets:
	bash $(SCRIPTS)/collect-assets.sh

rootfs:
	bash $(SCRIPTS)/build-rootfs.sh

image:
	bash $(SCRIPTS)/bake-image.sh
