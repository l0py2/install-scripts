#!/bin/sh

# Configuration section:

# Example: pt-latin1
KEYMAP=''
# Example: en_US.UTF-8
LOCALE=''
# Example: Europe/Lisbon
TIMEZONE=''

# Empty for UEFI boot mode
BIOS_DISK=''
# Empty for BIOS boot mode
EFI_PARTITION=''
# Values:
# 0 to disable EFI partition formatting
# 1 to enable EFI partition formatting
FORMAT_EFI_PARTITION=0
# Empty to disable Swap partition creation
SWAP_PARTITION=''
ROOT_PARTITION=''

HOSTNAME=''

# Example:
# amd-ucode for AMD processors
# intel-ucode for Intel processors
MICROCODE=''
PACSTRAP_PACKAGES="base linux linux-firmware $MICROCODE"
PACKAGES='networkmanager grub dash'

guide() {
	printf -- 'Arch base installation\n\n'
	printf -- '--start to start the installation\n'
}

efi_system=0

ls /sys/firmware/efi

if [ $? = 0 ]
then
	efi_system=1
fi

if [ "$1" = '--start' ]
then
	localectl set-keymap "$KEYMAP"

	umount -R /mnt

	mkfs.ext4 "$ROOT_PARTITION"
	
	mount "$ROOT_PARTITION" /mnt

	if [ $efi_system = 1 ]
	then
		if [ $FORMAT_EFI_PARTITION = 1 ]
		then
			mkfs.fat -F 32 "$EFI_PARTITION"
		fi

		mount --mkdir "$EFI_PARTITION" /mnt/boot
	fi

	if [ -n "$SWAP_PARTITION" ]
	then
		mkswap "$SWAP_PARTITION"

		swapon "$SWAP_PARTITION"
	fi

	pacstrap -K /mnt $PACSTRAP_PACKAGES

	genfstab -U /mnt >> /mnt/etc/fstab

	cp "$0" /mnt/install-script
	chmod 777 /mnt/install-script

	cp /etc/vconsole.conf /mnt/etc/vconsole.conf
	mkdir -p /mnt/etc/X11/xorg.conf.d
	cp /etc/X11/xorg.conf.d/00-keyboard.conf /mnt/etc/X11/xorg.conf.d/00-keyboard.conf

	arch-chroot /mnt /install-script --root
elif [ "$1" = '--root' ]
then
	pacman -S --noconfirm $PACKAGES

	ln -sf /usr/share/zoneinfo/$TIMEZONE /etc/localtime

	hwclock --systohc

	ln -sfT dash /usr/bin/sh

	cat << EOF > /usr/share/libalpm/hooks/shell-relink.hook
[Trigger]
Type = Package
Operation = Upgrade
Target = bash

[Action]
Description = Re-pointing /bin/sh to dash
When = PostTransaction
Exec = /usr/bin/ln -sfT dash /usr/bin/sh
Depends = dash
EOF

	sed -i "s/#$LOCALE/$LOCALE" /etc/locale.gen

	locale-gen

	cat << EOF > /etc/locale.conf
LANG=$LOCALE
EOF

	cat << EOF > /etc/hostname
$HOSTNAME
EOF

	cat << EOF > /etc/hosts
127.0.0.1	localhost
::1		localhost
127.0.1.1	$HOSTNAME
EOF

	systemctl enable NetworkManager.service


	if [ $efi_system -eq 1 ]
	then
		pacman -S --noconfirm efibootmgr

		grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB
	else
		grub-install --target=i386-pc "$BIOS_DISK"
	fi

	grub-mkconfig -o /boot/grub/grub.cfg

	passwd

	while [ $? -ne 0 ]
	do
		passwd
	done
else
	guide
fi
