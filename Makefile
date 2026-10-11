.PHONY: build collect rootfs deploy-sd deploy-adb-sd
build:
	./scripts/build.sh
collect:
	./scripts/collect-device.sh
rootfs:
	./scripts/rootfs.sh
deploy-sd:
	./scripts/deploy-sd.sh "$(BOOT_MOUNT)"

deploy-adb-sd:
	./scripts/deploy-adb-sd.sh
