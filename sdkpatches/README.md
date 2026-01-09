# SDK Patches
Follow this in case the patches fail/don't merge

## build.sh
We need to update the `__PACKAGE_ROOTFS()` function to support custom rootfs, replace it with the contents of `UPDATED_PACKAGE_ROOTFS.sh`

We also need to make it create an empty OEM package despite not actually using it (`RK_BUILD_APP_TO_OEM_PARTITION=n`). So add this section to the `build_firmware()` function in build.sh, find the `if [ "$RK_BUILD_APP_TO_OEM_PARTITION" = "y" ]; then` line and append this to the very end of the else case:
```sh
		if [[ $RK_PARTITION_CMD_IN_ENV =~ "oem" ]]; then
			mkdir -p $RK_PROJECT_OUTPUT/oem_empty
			build_mkimg $GLOBAL_OEM_NAME $RK_PROJECT_OUTPUT/oem_empty
			rm -rf $RK_PROJECT_OUTPUT/oem_empty
		fi
```
In the future I need to figure out how to just skip having the OEM partition entirely, kinda a waste of space.

## sysdrv/Makefile
We want the full /lib/modules/ structure, not just a flat list of KOs. So we change the "build driver ko" step (`drv: prepare`)

**Replace these lines**:
```sh
	$(AT)find $(KERNEL_DIR_DRV_KO)/lib/modules/*/kernel \
		-name "*.ko" -type f -exec cp -fav {} $(SYSDRV_KERNEL_MOD_PATH) \;
```
with
```sh
$(AT)cp -rfa $(KERNEL_DIR_DRV_KO)/lib $(SYSDRV_KERNEL_MOD_PATH)/
```
