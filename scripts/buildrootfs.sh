#!/bin/bash
sudo APK_OPTS="--arch armhf --allow-untrusted --no-progress -X http://dl-cdn.alpinelinux.org/alpine/v3.15/community"   ./alpine-make-rootfs   --branch v3.15   --timezone Asia/Jakarta   --packages "alpine-baselayout busybox openrc apk-tools shadow \
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
              busybox-initscripts \
              ifupdown-ng \
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
              wireless-regdb"  ./alpine-armhf-ultimate.tar.gz --script-chroot - <<'SHELL'  # ==========================================
  # CONFIGURATION
  # ==========================================
  TARGET_DISK="/dev/mmcblk1"
  ROOT_PART_NUM="7"
  ROOT_PARTITION="${TARGET_DISK}p${ROOT_PART_NUM}"

  # Export PATH for tools
  export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin


  # --- 1. mdev Configuration ---
  # Configure mdev to auto-load drivers
  cat > /etc/mdev.conf <<EOF
\$MODALIAS=.* root:root 660 @modprobe -b "\$MODALIAS"
input/.* root:input 660
snd/.* root:audio 660
tty[0-9]* root:tty 660
sd[a-z].* root:disk 660
mmcblk[0-9].* root:disk 660
tun[0-9]* root:netdev 660 =net/tun
tap[0-9]* root:netdev 660 =net/tap
EOF

# --- 1.1 Custom Net Watchdog (Conflict-Free Version) ---
  # This script monitors the cable. When plugged in, it forces the interface
  # DOWN first (to allow MAC change), then brings it UP (to start DHCP).
  cat > /usr/local/bin/net-watchdog <<EOF
#!/bin/sh
IFACE="eth0"

while true; do
  # 1. WAKE UP: Force L1/L2 up so the driver can read the PHY status.
  ip link set \$IFACE up >/dev/null 2>&1
  
  # 2. READ STATUS
  # Short sleep to let the PHY electronics wake up
  usleep 200000
  CARRIER=\$(cat /sys/class/net/\$IFACE/carrier 2>/dev/null || echo 0)
  HAS_IP=\$(ip -4 addr show \$IFACE | grep -q "inet" && echo 1 || echo 0)

  # 3. LOGIC
  if [ "\$CARRIER" = "1" ] && [ "\$HAS_IP" = "0" ]; then
     echo "Net Watchdog: Link Detected. Resetting interface..."
     
     # CRITICAL: Force DOWN. This ensures 'ifup' can apply the 
     # 'pre-up' MAC address change safely.
     ip link set \$IFACE down
     
     echo "Net Watchdog: Starting DHCP..."
     ifup \$IFACE
     
  elif [ "\$CARRIER" = "0" ] && [ "\$HAS_IP" = "1" ]; then
     echo "Net Watchdog: Link Lost. Stopping DHCP..."
     ifdown \$IFACE
  fi
  
  sleep 3
done
EOF
  chmod +x /usr/local/bin/net-watchdog

  # Create the OpenRC Service for the Watchdog
  cat > /etc/init.d/net-watchdog <<EOF
#!/sbin/openrc-run
command="/usr/local/bin/net-watchdog"
command_background=true
pidfile="/run/net-watchdog.pid"
description="Simple Network Hotplug Watcher"

depend() {
    need localmount
    after networking
}
EOF
  chmod +x /etc/init.d/net-watchdog

  

  # --- 2. Filesystem Setup ---
  mkdir -p /dev/pts /proc /sys
  cat > /etc/fstab <<EOF
devpts      /dev/pts     devpts    gid=5,mode=620   0 0
proc        /proc        proc      defaults         0 0
sysfs       /sys         sysfs     defaults         0 0
tmpfs       /tmp         tmpfs     defaults         0 0
# $ROOT_PARTITION  /            ext4      noatime      0 1
EOF

  # --- 3. Service Setup ---
  rc-update add devfs sysinit
  rc-update add procfs sysinit
  rc-update add sysfs sysinit
  rc-update add mdev sysinit
  rc-update add hwdrivers sysinit
  rc-update add networking boot
  rc-update add wpa_supplicant boot
  rc-update add rngd boot
  rc-update add swap boot
  rc-update add sshd default
  rc-update add chronyd default
  rc-update add net-watchdog default
  rc-update add bluetooth default

  # --- 4. PERSISTENT MAC SERVICE (EARLY BOOT) ---
cat > /etc/init.d/mac-restore <<EOF
#!/sbin/openrc-run
description="Generate stable MAC address from CPU serial"

depend() {
    need localmount
    before networking
}

start() {
    ebegin "Provisioning Persistent MAC"
    
    # 1. Generate MAC (a2:xx:xx...)
    STABLE_MAC=\$(awk '/Serial/ {print \$3}' /proc/cpuinfo | tail -c 11 | sed 's/^\(.*\)/a2\1/' | sed 's/\(..\)/\1:/g;s/:$//')
    
    # 2. Inject PRE-UP rule
    # We use 'pre-up' which works perfectly with the full 'ifupdown' package.
    if [ -n "\$STABLE_MAC" ] && grep -q "iface eth0 inet dhcp" /etc/network/interfaces; then
         # Only inject if not already present
         if ! grep -q "pre-up ip link set eth0 address" /etc/network/interfaces; then
             echo "    pre-up ip link set eth0 address \$STABLE_MAC" >> /etc/network/interfaces
             einfo "MAC Fixed: \$STABLE_MAC"
         fi
         
         # Optional: Hostname
         MAC_SUFFIX=\$(echo "\$STABLE_MAC" | awk -F: '{print \$5\$6}')
         echo "luckfox-\$MAC_SUFFIX" > /etc/hostname
         hostname -F /etc/hostname
    fi
    
    # 3. Self Destruct
    rc-update del mac-restore boot
    rm -f /etc/init.d/mac-restore
    eend 0
}
EOF
  chmod +x /etc/init.d/mac-restore
  rc-update add mac-restore boot

  # --- 5. FIRST BOOT PROVISIONING SCRIPT ---
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

        # Rescan hardware now that drivers are actually present
        mdev -s

        ebegin "Rebooting to apply driver changes..."
        reboot

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

  # --- 6. SSH Configuration ---
  ssh-keygen -A
  sed -i 's/^#*PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config
  sed -i 's/^#*PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config
  sed -i 's|^#*Subsystem.*sftp.*|Subsystem sftp /usr/lib/ssh/sftp-server|' /etc/ssh/sshd_config

  # --- 7. Console ---
  sed -i '/^tty[1-6]::/d' /etc/inittab
  echo "ttyFIQ0::respawn:/sbin/agetty --autologin root ttyFIQ0 vt100" >> /etc/inittab
  echo ttyFIQ0 >> /etc/securetty

  # --- 8. Network ---
  echo "allow-hotplug eth0" >> /etc/network/interfaces
  echo "iface eth0 inet dhcp" >> /etc/network/interfaces

  # --- 9. User Configuration ---
  awk -F: 'FNR==NR {seen[$1]=1; next} !($1 in seen) {print $1":!:19700:0:99999:7:::"}' /etc/shadow /etc/passwd >> /etc/shadow
  echo "root:linux" | chpasswd
  adduser -D -s /bin/bash alpine
  awk -F: 'FNR==NR {seen[$1]=1; next} !($1 in seen) {print $1":!:19700:0:99999:7:::"}' /etc/shadow /etc/passwd >> /etc/shadow
  echo "alpine:linux" | chpasswd
  addgroup alpine wheel
  echo "%wheel ALL=(ALL:ALL) ALL" > /etc/sudoers.d/wheel
SHELL
