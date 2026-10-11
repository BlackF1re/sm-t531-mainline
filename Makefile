.PHONY: build collect rootfs deploy-sd
build:
	./scripts/build.sh
collect:
	./scripts/collect-device.sh
rootfs:
	./scripts/rootfs.sh
deploy-sd:
	./scripts/deploy-sd.sh "$(BOOT_MOUNT)"
