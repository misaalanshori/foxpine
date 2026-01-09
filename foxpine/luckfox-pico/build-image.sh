#!/bin/bash
pushd output/image
sed -i 's/6G(rootfs)/100G(rootfs)/' .env.txt
../../sysdrv/tools/pc/uboot_tools/mkenvimage -s 0x8000 -p 0x0 -o env.img .env.txt
sudo ./blkenvflash ../../alpine-$(date +%Y%m%d%H%M%S).img
popd