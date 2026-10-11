.PHONY: build bootstrap collect rootfs deploy-sd deploy-adb-sd
build:
	./scripts/build.sh
bootstrap:
	./scripts/build.sh bootstrap
collect:
	./scripts/collect-device.sh
rootfs:
	./scripts/rootfs.sh
deploy-sd:
	./scripts/deploy-sd.sh "$(BOOT_MOUNT)"

deploy-adb-sd:
	./scripts/deploy-adb-sd.sh
