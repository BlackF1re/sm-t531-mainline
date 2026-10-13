BOOT_MODE ?= sd

.PHONY: build bootstrap rescue-initramfs collect rootfs powerdevil deploy-sd deploy-adb-sd
build:
	./scripts/build.sh
bootstrap:
	./scripts/build.sh bootstrap
rescue-initramfs:
	./scripts/build-initramfs.sh bootstrap
collect:
	./scripts/collect-device.sh
rootfs:
	./scripts/rootfs.sh
powerdevil:
	./scripts/build-powerdevil.sh
deploy-sd:
	BOOT_MODE="$(BOOT_MODE)" ./scripts/deploy-sd.sh "$(BOOT_MOUNT)"

deploy-adb-sd:
	./scripts/deploy-adb-sd.sh
