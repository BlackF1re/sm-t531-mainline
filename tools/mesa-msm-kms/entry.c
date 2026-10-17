// SPDX-License-Identifier: MIT
/* Mesa25 platform loader entry for the upstream split MSM KMS driver. */
#include <dlfcn.h>
#include <stddef.h>

static const void *platform_extensions(void)
{
	static const void *(*extensions)(void);
	static void *library;

	if (!extensions) {
		library = dlopen("/usr/lib/arm-linux-gnueabihf/dri/mediatek_dri.so",
				 RTLD_NOW | RTLD_LOCAL);
		if (!library)
			return NULL;
		extensions = dlsym(library, "__driDriverGetExtensions_mediatek");
	}
	return extensions ? extensions() : NULL;
}

/* The loader may retain the DRM name or normalize its dash. */
const void *msm_kms_extensions(void)
	__asm__("\"__driDriverGetExtensions_msm-kms\"");
const void *msm_kms_extensions(void)
{
	return platform_extensions();
}

const void *__driDriverGetExtensions_msm_kms(void)
{
	return platform_extensions();
}
