# Telmi-os 0.2.3 — image V30 + packs DTB ArkOS4Clone + Select-DTB.
SHELL := /bin/bash
ROOT := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))
PARENT := $(abspath $(ROOT)/..)
LINUX := $(PARENT)/third_party/linux
SCRIPTS := $(ROOT)/scripts
VERSION := $(shell tr -d '[:space:]' < $(ROOT)/VERSION)

.PHONY: help all toolchain kernel dtb uboot telmi assets rootfs image image-v20

help:
	@echo "telmi-os $(VERSION) — V30 + image V20 optionnelle"
	@echo "  make toolchain  Linaro 6.3.1 -> ../cache/toolchains/"
	@echo "  make kernel     Image telmi_defconfig"
	@echo "  make dtb        v30 (dtc) + v20 (cpp+dtc type2)"
	@echo "  make uboot      idbloader / uboot.img / trust.img"
	@echo "  make telmi      storyTeller bootScreen batmon"
	@echo "  make assets     PNG/TTF depuis le labo -> staging"
	@echo "  make rootfs     debootstrap minbase (root)"
	@echo "  make image      output/soysauce-$(VERSION).img V30 (root)"
	@echo "  make image-v20  output/soysauce-$(VERSION)-v20.img (root)"
	@echo "  make all        toolchain kernel dtb uboot telmi"

all: toolchain kernel dtb uboot telmi

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

image-v20:
	bash $(SCRIPTS)/build-dtb.sh
	bash $(SCRIPTS)/bake-v20.sh
