BOOT_MODE ?= sd

.PHONY: check build mesa bootstrap rescue-initramfs collect rootfs powerdevil deploy-sd deploy-adb-sd
build:
	./scripts/build.sh
mesa:
	./scripts/build-mesa.sh
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

# Host-only: no compilation, flashing, network access, or tablet interaction.
check:
	python3 -B tools/check-repository.py
	python3 -B -m unittest discover -s tests
