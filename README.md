# Foxpine
Creating the most ***complete*** (~~bloated~~) Alpine image for the Luckfox Pico (Mini B specifically).

You can try following these as instructions, but these are mostly for my own reference so I don't forget how to do it. Most of the hardwork is done by the Luckfox Pico SDK by Luckfox themselves. We just need to reconfigure things and provide our own rootfs.

At the current state, this may or may not work. Just try it out I guess, I think it'll work but may have issues during runtime. My goal is to make the most compatible Alpine image where I can plug or do things and it would just work, kinda like a Raspberry Pi experience. But worse cause this thing only got 64MB of RAM.

You may also be interested in checking my gist for my collection of the scattered messy notes I took: [Luckfox Pico Notes](https://gist.github.com/misaalanshori/7b03321733827e364d5fa53e1e842fa9).

**The current state is** that I'm trying to get the kernel modules to be copied with its original structure so it can be processed by `depmod -a` properly. Also I'm testing if moving to Alpine v3.15 would give me uncompressed firmware files, because the kernel does not support zstd compressed firmware files while the latest versions of Alpine gives you .zst compressed firmares.

A lot of this is based/inspired by [Femtofox/Foxbuntu](https://github.com/femtofox/femtofox), so you might also want to use the Luckfox SDK forked at [`https://github.com/Ruledo/luckfox-pico.git`](https://github.com/Ruledo/luckfox-pico.git) like they do, but I'm pretty sure the original SDK at [`https://github.com/LuckfoxTECH/luckfox-pico`](https://github.com/LuckfoxTECH/luckfox-pico) should work just fine since we don't use Ubuntu.

## Preparing an Alpine rootfs
Let's just start with making a rootfs first using [alpine-make-rootfs](https://github.com/alpinelinux/alpine-make-rootfs). Make it however you want, you can use the one I made at `foxpine/scripts/buildrootfs.sh` or just use it as a reference. It has basically all the packages I would ever need, but also a chroot script with inside it contains a firstboot script that will expand the rootfs to fill the partition, merge the OEM content (kernel modules and extra binaries), and create a swapfile. 
> [!WARNING]
> You may (or more likely will) need `qemu-user-static` to build the rootfs since **we are targeting armhf**.


## Preparing the SDK
After cloning the SDK, we need to sync our Foxpine changes to the SDK including allowing a custom rootfs to be used. 
First just sync the changes using rsync:
```sh
rsync -aHAXv --progress --keep-dirlinks --itemize-changes \
    foxpine/foxpine/sysdrv luckfox-pico/sysdrv/
rsync -aHAXv --progress --keep-dirlinks --itemize-changes \
    foxpine/foxpine/project/ luckfox-pico/project/
rsync -aHAXv --progress --keep-dirlinks --itemize-changes \
    foxpine/foxpine/output/image/ luckfox-pico/output/image/
```
**Then you need to apply the patches to the SDK** to allow a custom rootfs to be used and some makefile changes for the kernel modules. You can find the patches at `foxpine/sdkpatches`.

## Building the SDK
We can set it up like usual targeting Buildroot.
```sh
# Configure the Environment
cd luckfox-pico
./build.sh env
# SELECT: [2] Luckfox Pico Mini B -> [0] SDCard -> [0] Buildroot

# Build U-Boot
./build.sh uboot

# Configure and build Kernel
./build.sh kernelconfig
# Keep default or change as needed, then we build kernel and drivers:
./build.sh driver
```

At this point we **skip building the rootfs**, since we have already built our own, so this is a good time to copy your rootfs to the SDK at `luckfox-pico/sysdrv/custom_rootfs/alpine-armhf-ultimate.tar.gz`

Then we can continue by building the firmware:
```sh
# Build the firmware images as root
sudo ./build.sh firmware

# Then we can build a complete image
cd output/image

# Fix rootfs partition size in env config
sudo sed -i 's/6G(rootfs)/100G(rootfs)/' .env.txt

# Generate env image
sudo ../../sysdrv/tools/pc/uboot_tools/mkenvimage -s 0x8000 -p 0x0 -o env.img .env.txt

# Pack the final image
sudo ./blkenvflash ../../alpine.img
```

Now you have an `alpine.img` you can flash with whatever you want, I've been using Balena Etcher so far (Rufus didn't want to work with the raw images for some reason, Etcher also complained but still worked)

## Docker
For my and possibly your convenience, I've been using Docker to build the SDK and rootfs. You can find the Docker stuff at `foxpine/docker`. 
> [!WARNING]
> These source code and build files doesn't like being stored in a Windows file system, so you **must use a Linux environment** like wsl2/docker and keep everything in its Linux file systems, like keeping it in a Docker volume (**NOT** a mounted folder).