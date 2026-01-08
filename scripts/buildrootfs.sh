#!/bin/bash
sudo APK_OPTS="--arch armhf --allow-untrusted --no-progress"   ./alpine-make-rootfs   --keys-dir ./keys   --branch v3.15   --timezone Asia/Jakarta   --packages "alpine-baselayout busybox openrc apk-tools shadow \
              bash bash-completion nano htop bpytop file \
              grep sed gawk \
              tar gzip bzip2 xz zstd \
              pigz zip unzip p7zip \
              wget curl openssh openssh-sftp-server \
              iw net-tools iproute2 wpa_supplicant wireless-tools \
              bind-tools ca-certificates \
              ethtool tcpdump socat bluez  \
              sudo parted mmc-utils \
              e2fsprogs e2fsprogs-extra \
              cloud-utils-growpart \
              usbutils util-linux util-linux-misc usb-modeswitch pciutils \
              lm-sensors i2c-tools libgpiod rng-tools \
              tmux neofetch chrony \
              python3 git \
              linux-firmware-none \
              linux-firmware-brcm \
              linux-firmware-cypress \
              linux-firmware-ath10k \
              linux-firmware-ath9k_htc \
              linux-firmware-rtlwifi \
              linux-firmware-rtlwifi \
              linux-firmware-mediatek \
              linux-firmware-mrvl \
              linux-firmware-intel \
              linux-firmware-other \
              wireless-regdb"  ./alpine-armhf-ultimate-v3.15.tar.gz --script-chroot - <<'SHELL'  # ==========================================
  # CONFIGURATION
  # ==========================================
  TARGET_DISK="/dev/mmcblk1"
  ROOT_PART_NUM="7"
  ROOT_PARTITION="${TARGET_DISK}p${ROOT_PART_NUM}"

  # Export PATH for tools
  export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

  # --- 1. Filesystem Setup ---
  mkdir -p /dev/pts /proc /sys
  cat > /etc/fstab <<EOF
devpts      /dev/pts     devpts    gid=5,mode=620   0 0
proc        /proc        proc      defaults         0 0
sysfs       /sys         sysfs     defaults         0 0
tmpfs       /tmp         tmpfs     defaults         0 0
# $ROOT_PARTITION  /            ext4      noatime      0 1
EOF

  # --- 2. Service Setup ---
  rc-update add devfs sysinit
  rc-update add procfs sysinit
  rc-update add sysfs sysinit
  rc-update add networking boot
  rc-update add wpa_supplicant boot
  rc-update add sshd default
  rc-update add chronyd default
  rc-update add rngd boot
  rc-update add bluetooth default

# --- 3. FIRST BOOT PROVISIONING SCRIPT ---
  # We use EOF (unquoted) so $ROOT_PARTITION expands NOW (during build),
  # but we escape \$KERNEL_VERSION so it expands LATER (during boot).
  cat > /etc/init.d/firstboot-provision <<EOF
#!/sbin/openrc-run

depend() {
    after localmount
}

start() {
    # --- STAGE 2: Post-Reboot Provisioning ---
    if [ -f /etc/rootfs-expanded ]; then

        # A. Resize Filesystem
        ebegin "Provisioning: Resizing Filesystem ($ROOT_PARTITION)"
        if [ -x /sbin/resize2fs ]; then
            /sbin/resize2fs $ROOT_PARTITION > /dev/null
        elif [ -x /usr/sbin/resize2fs ]; then
            /usr/sbin/resize2fs $ROOT_PARTITION > /dev/null
        fi
        eend \$?

        # B. Merge OEM Partition Content
        if [ -d "/oem/usr" ]; then
            ebegin "Provisioning: Merging OEM Content"
            # 1. Handle Kernel Modules (Special Case: /oem/usr/ko/lib -> /lib)
            if [ -d "/oem/usr/ko/lib/modules" ]; then
                # Ensure destination exists
                mkdir -p /lib/modules
                # Copy contents
                cp -rfa /oem/usr/ko/lib/modules/* /lib/modules/ 2>/dev/null
                einfo "Merged Kernel Modules"
                depmod -a
            fi
            # 2. Merge strict /usr directories (bin, lib, share)
            # We copy specific subfolders to avoid copying 'ko' into /usr/ko
            for dir in bin lib share; do
                if [ -d "/oem/usr/\$dir" ]; then
                    mkdir -p "/usr/\$dir"
                    cp -rfa /oem/usr/\$dir/* "/usr/\$dir/" 2>/dev/null
                    einfo "Merged /usr/\$dir"
                fi
            done
            # Cleanup
            rm -rf /oem
            eend \$?
        else
            ewarn "Provisioning: No OEM content found"
        fi

        # C. Create Swapfile
        if [ ! -f /swapfile ]; then
            ebegin "Provisioning: Creating 512MB Swapfile"
            fallocate -l 512M /swapfile
            chmod 600 /swapfile
            mkswap /swapfile > /dev/null
            swapon /swapfile > /dev/null
            echo '/swapfile none swap sw 0 0' >> /etc/fstab
            eend \$?
        fi

        # D. CLEANUP
        rm -f /etc/rootfs-expanded
        rc-update del firstboot-provision default
        rm -f /etc/init.d/firstboot-provision

    # --- STAGE 1: First Boot Partition Expand ---
    else
        ebegin "Provisioning: Expanding Partition Table"
        growpart $TARGET_DISK $ROOT_PART_NUM > /dev/null 2>&1
        touch /etc/rootfs-expanded
        eend \$?
        ebegin "Rebooting to apply partition changes..."
        reboot
    fi
}
EOF
  chmod +x /etc/init.d/firstboot-provision
  rc-update add firstboot-provision default

  # --- 4. SSH Configuration ---
  ssh-keygen -A
  sed -i 's/^#*PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config
  sed -i 's/^#*PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config
  sed -i 's|^#*Subsystem.*sftp.*|Subsystem sftp /usr/lib/ssh/sftp-server|' /etc/ssh/sshd_config

  # --- 5. Console ---
  sed -i '/^tty[1-6]::/d' /etc/inittab
  echo "ttyFIQ0::respawn:/sbin/agetty --autologin root ttyFIQ0 vt100" >> /etc/inittab
  echo ttyFIQ0 >> /etc/securetty

  # --- 6. Network ---
  echo "auto eth0" >> /etc/network/interfaces
  echo "iface eth0 inet dhcp" >> /etc/network/interfaces

  # --- 7. User Configuration ---
  awk -F: 'FNR==NR {seen[$1]=1; next} !($1 in seen) {print $1":!:19700:0:99999:7:::"}' /etc/shadow /etc/passwd >> /etc/shadow
  echo "root:linux" | chpasswd
  adduser -D -s /bin/bash alpine
  awk -F: 'FNR==NR {seen[$1]=1; next} !($1 in seen) {print $1":!:19700:0:99999:7:::"}' /etc/shadow /etc/passwd >> /etc/shadow
  echo "alpine:linux" | chpasswd
  addgroup alpine wheel
  echo "%wheel ALL=(ALL:ALL) ALL" > /etc/sudoers.d/wheel
SHELL
