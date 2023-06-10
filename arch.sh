#!/bin/sh

# Before runnig edit at least the general configuration

# Configuration variables
KEYMAP="pt-latin1"

FORMAT_EFI_PARTITION=0
EFI_PARTITION=""
ROOT_PARTITION=""
SWAP_PARTITION="" # Leave it empty if you don't want Swap

TIME_ZONE="Europe/Lisbon"
LOCALE="en_US.UTF-8"

HOSTNAME="lp"
USERNAME="lp2"

# Script variables
MICROCODE="intel-ucode"
FIRMWARE_PACKAGES="mesa sof-firmware alsa-firmware"
DEPENDENCY_PACKAGES="gtk4 qt5-wayland qt6-wayland"
BOOT_LOADER_PACKAGES="grub efibootmgr"
BASE_PACKAGES="sudo networkmanager base-devel git rustup openssh ttf-nerd-fonts-symbols starship"
AUDIO_PACKAGES="pipewire wireplumber pipewire-audio pipewire-alsa pipewire-pulse pipewire-jack"
USER_PACKAGES="xdg-desktop-portal-wlr dunst polkit polkit-gnome wofi udisks2 waybar"
UTIL_PACKAGES="neovim man-db man-pages texinfo kitty"
AUR_PACKAGES="hyprland-git swww"

if [ -z "$1" ]
then
	umount -R /mnt

	loadkeys $KEYMAP

	mkfs.ext4 -F $ROOT_PARTITION

	if [ $FORMAT_EFI_PARTITION -eq 1 ]
	then
		mkfs.fat -F 32 $EFI_PARTITION
	fi

	if [ -n "$SWAP_PARTITION" ]
	then
		mkswap $SWAP_PARTITION
	fi

	mount $ROOT_PARTITION /mnt

	mount --mkdir $EFI_PARTITION /mnt/boot

	if [ -n "$SWAP_PARTITION" ]
	then
		swapon $SWAP_PARTITION
	fi

	pacstrap -K /mnt base linux linux-firmware

	genfstab -U /mnt >> /mnt/etc/fstab

	cp $0 /mnt/install-script

	chmod 777 /mnt/install-script

	arch-chroot /mnt /install-script root

	rm /mnt/install-script
elif [ "$1" = "root" ]
then
	if [ -n "$MICROCODE" ]
	then
		pacman -S --noconfirm $MICROCODE
	fi

	if [ -n "$FIRMWARE_PACKAGES" ]
	then
		pacman -S --noconfirm $FIRMWARE_PACKAGES
	fi

	if [ -n "$DEPENDENCY_PACKAGES" ]
	then
		pacman -S --noconfirm $DEPENDENCY_PACKAGES
	fi

	if [ -n "$BOOT_LOADER_PACKAGES" ]
	then
		pacman -S --noconfirm $BOOT_LOADER_PACKAGES
	fi

	if [ -n "$BASE_PACKAGES" ]
	then
		pacman -S --noconfirm $BASE_PACKAGES
	fi

	if [ -n "$AUDIO_PACKAGES" ]
	then
		pacman -S --noconfirm $AUDIO_PACKAGES
	fi

	if [ -n "$USER_PACKAGES" ]
	then
		pacman -S --noconfirm $USER_PACKAGES
	fi

	if [ -n "$UTIL_PACKAGES" ]
	then
		pacman -S --noconfirm $UTIL_PACKAGES
	fi

	ln -sf /usr/share/zoneinfo/$TIME_ZONE /etc/localtime

	hwclock --systohc
	
	sed -i "s/#$LOCALE/$LOCALE/" /etc/locale.gen

	locale-gen

	echo "LANG=$LOCALE" > /etc/locale.conf

	echo "KEYMAP=$KEYMAP" > /etc/vconsole.conf

	echo $HOSTNAME > /etc/hostname

	echo -e "127.0.0.1\tlocalhost" > /etc/hosts
	echo -e "::1\t\tlocalhost" >> /etc/hosts
	echo -e "127.0.1.1\t$HOSTNAME" >> /etc/hosts

	grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB

	grub-mkconfig -o /boot/grub/grub.cfg

	useradd -m -G wheel $USERNAME

	echo "%wheel ALL=(ALL:ALL) NOPASSWD: ALL # temp" >> /etc/sudoers

	systemctl enable NetworkManager.service

	echo -e "\n\n\nInsert root password"

	passwd

	echo -e "\n\n\nInsert user password"

	passwd $USERNAME
	
	sudo -u $USERNAME /install-script user

	sed -i "\$d" /etc/sudoers

	echo "%wheel ALL=(ALL:ALL) ALL" >> /etc/sudoers
elif [ "$1" = "user" ]
then
	rustup default stable

	cd $HOME

	mkdir repositories

	cd repositories

	git clone https://aur.archlinux.org/paru.git

	cd paru

	makepkg -si --noconfirm

	paru --gendb

	cd ..

	git clone https://github.com/l0py2/dotfiles --separate-git-dir=$HOME/.dotfiles

	rm dotfiles/.git

	cp dotfiles/. $HOME

	cd $HOME

	rm -rf repositories

	git --git-dir=.dotfiles --work-tree=$HOME config status.showUntrackedFiles no

	if [ -n "$AUR_PACKAGES" ]
	then
		paru -S --noconfirm $AUR_PACKAGES
	fi
fi
