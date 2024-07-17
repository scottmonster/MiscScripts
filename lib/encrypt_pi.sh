#/bin/bash

# https://github.com/ViRb3/pi-encrypted-boot-ssh


apt update
apt install -y kpartx cryptsetup-bin qemu-user-static


orig_img=""

mkdir pi
cd pi
cp "$orig_img" pi-base.img
cp pi-base.img pi-target.img
dd if=/dev/zero bs=1G count=1 >> pi-target.img
parted pi-target.img resizepart 2 100%
kpartx -ar "$PWD/pi-base.img"
kpartx -a "$PWD/pi-target.img"
mkdir -p /mnt/original/
mount /dev/mapper/loop0p2 /mnt/original/
cryptsetup luksFormat -c xchacha20,aes-adiantum-plain64 --pbkdf-memory 512000 --pbkdf-parallel=1 /dev/mapper/loop1p2

cryptsetup open /dev/mapper/loop1p2 crypted

mkfs.ext4 /dev/mapper/crypted
mkdir -p /mnt/chroot/
mount /dev/mapper/crypted /mnt/chroot/
rsync --archive --hard-links --acls --xattrs --one-file-system --numeric-ids --info="progress2" /mnt/original/* /mnt/chroot/

mkdir -p /mnt/chroot/boot/
mount /dev/mapper/loop1p1 /mnt/chroot/boot/
mount -t proc none /mnt/chroot/proc/
mount -t sysfs none /mnt/chroot/sys/
mount -o bind /dev /mnt/chroot/dev/
mount -o bind /dev/pts /mnt/chroot/dev/pts/
LANG=C chroot /mnt/chroot/ /bin/bash
apt update
apt install busybox cryptsetup dropbear-initramfs patch curl jq findutils -y


# cat /etc/fstab
# proc            /proc           proc    defaults          0       0
# PARTUUID=7788c428-01  /boot/firmware  vfat    defaults          0       2
# PARTUUID=7788c428-02  /               ext4    defaults,noatime  0       1
# changed to:
# proc            /proc           proc    defaults          0       0
# PARTUUID=7788c428-01  /boot/firmware  vfat    defaults          0       2
# /dev/mapper/crypted  /               ext4    defaults,noatime  0       1


blkid | grep -Po ".*1p2.*crypto_LUKS.*"
/dev/mapper/loop1p2: UUID="5feb711d-30ff-45ca-8397-9b8dea5eb4ec" TYPE="crypto_LUKS" PARTUUID="7788c428-02"

echo 'crypted UUID=5feb711d-30ff-45ca-8397-9b8dea5eb4ec none luks,initramfs' >> /etc/crypttab


# cat /boot/cmdline.txt
# console=serial0,115200 console=tty1 root=PARTUUID=7788c428-02 rootfstype=ext4 fsck.repair=yes rootwait quiet init=/usr/lib/raspberrypi-sys-mods/firstboot
# change root= so that:
# console=serial0,115200 console=tty1 root=/dev/mapper/crypted cryptdevice=UUID=5feb711d-30ff-45ca-8397-9b8dea5eb4ec:crypted rootfstype=ext4 fsck.repair=yes rootwait quiet init=/usr/lib/raspberrypi-sys-mods/firstboot
# this is later changed again... right after building initramfs... we can probably do it in one shot

echo "CRYPTSETUP=y" >> /etc/cryptsetup-initramfs/conf-hook
patch --no-backup-if-mismatch /usr/share/initramfs-tools/hooks/cryptroot << 'EOF'
--- cryptroot
+++ cryptroot
@@ -33,7 +33,7 @@
         printf '%s\0' "$target" >>"$DESTDIR/cryptroot/targets"
         crypttab_find_entry "$target" || return 1
         crypttab_parse_options --missing-path=warn || return 1
-        crypttab_print_entry
+        printf '%s %s %s %s\n' "$_CRYPTTAB_NAME" "$_CRYPTTAB_SOURCE" "$_CRYPTTAB_KEY" "$_CRYPTTAB_OPTIONS" >&3
     fi
 }
EOF

sed -i 's/^TIMEOUT=.*/TIMEOUT=100/g' /usr/share/cryptsetup/initramfs/bin/cryptroot-unlock
keys=$(curl https://api.github.com/users/scottmonster/keys | jq -r '.[].key')
echo -n "$keys" >>/etc/dropbear/initramfs/authorized_keys

ls /lib/modules/

#  use 6.1.0-rpi4-rpi-v8 unless youre on pi5
echo "CONFIG_RD_ZSTD=y" > /boot/config-6.1.0-rpi4-rpi-v8
mkinitramfs -o /boot/initramfs8 "6.1.0-rpi4-rpi-v8"
rm /boot/config-6.1.0-rpi4-rpi-v8



tee -a /boot/firstrun.sh > /dev/null <<EOF
#!/bin/bash
set +e

/usr/lib/raspberrypi-sys-mods/imager_custom enable_ssh
/usr/lib/raspberrypi-sys-mods/regenerate_ssh_host_keys

rm -f /boot/firstrun.sh
sed -i 's| systemd.run.*||g' /boot/cmdline.txt
exit 0
EOF
chmod +x /boot/firstrun.sh
sync
history -c && exit
umount /mnt/chroot/boot
umount /mnt/chroot/sys
umount /mnt/chroot/proc
umount /mnt/chroot/dev/pts
umount /mnt/chroot/dev
umount /mnt/chroot
cryptsetup close crypted
umount /mnt/original
rm -d /mnt/chroot
rm -d /mnt/original
kpartx -d "$PWD/pi-base.img"
kpartx -d "$PWD/pi-target.img"

# cp it to the same directory it came from
cp pi-target.img /home/scott/downloads/pi/pi-target.img
chown scott:scott /home/scott/downloads/pi/pi-target.img

cd ..
rm -rf pi
exit


# IMPORTANT! After first boot the file system needs to be expanded manual with:
# /dev/xxx should be the actual block device
parted /dev/xxx resizepart 2 100%
cryptsetup resize crypted
resize2fs /dev/mapper/crypted






sudo apt-get remove --purge wolfram-engine scratch nuscratch sonic-pi pistore idle3 smartsim penguinspuzzle java-common minecraft-pi python-minecraftpi python3-minecraftpi libx11-6 libgtk-3-common xkb-data lxde-icon-theme raspberrypi-artwork

sudo apt-get remove --auto-remove --purge libx11-.* x11-common
dpkg -l | grep ^rc | cut -d' ' -f3|xargs sudo dpkg -P





maxtime=30
threads=4
sysbench --test=cpu --threads=$threads --time=$maxtime run
sysbench --test=memory --threads=1 --time=$maxtime --memory-total-size=1G --memory-oper=write --memory-access-mode=rnd run
sysbench --test=memory --threads=1 --time=$maxtime --memory-total-size=1G --memory-oper=read --memory-access-mode=rnd run
sysbench --test=threads --threads=$threads --time=$maxtime run
sysbench --test=fileio --threads=$threads --time=$maxtime --file-total-size=5G --file-test-mode=rndrw prepare
sysbench --test=fileio --threads=$threads --time=$maxtime --file-total-size=5G --file-test-mode=rndrw run
rm test_file*








