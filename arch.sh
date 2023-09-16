#!/bin/sh

if [ ! $1 ] || [ "$1" = '--help' ]
then
	printf 'Automated Arch Linux install script quick guide\n\n'
	printf 'Use --init to start an new configuration\n'
	printf 'Use --install to install based on the current configuration\n'
elif [ "$1" = '--init' ]
then
	whiptail --title 'Arch Linux install script' --msgbox \
		'Welcome to l0py2 automated Arch Linux install script' 0 0

	KEYMAPS=$(localectl list-keymaps | awk '{print $1" "$1}' | tr '\n' ' ')

	KEYMAP=$(whiptail --title 'Keymap' --nocancel --notags --menu \
		'Select the desired keymap' 0 0 0 $KEYMAPS \
		3>&1 1>&2 2>&3)

	loadkeys "$KEYMAP"

	whiptail --title 'Disk partitioning' --yesno \
		'Have you already partitioned the desired partitions for the installation' 0 0

	if [ $? -eq 1 ]
	then
		PARTITION_UTILITY=$(whiptail --title 'Disk partitioning' --nocancel --notags --menu \
			'Select fdisk or cfdisk for partitioning' 0 0 0 \
			'fdisk' 'fdisk' \
			'cfdisk' 'cfdisk' \
			3>&1 1>&2 2>&3)

		DISKS=$(lsblk -ln | grep 'disk' | awk '{print $1" "$1}' | tr '\n' ' ')

		CONTINUE_PARTITIONING=0

		while [ $CONTINUE_PARTITIONING -eq 0 ]
		do
			PARTITION_OPTION=$(whiptail --title 'Disk partitioning' --nocancel --notags --menu \
				'Select the desired disk to partition' 0 0 0 $DISKS \
				3>&1 1>&2 2>&3)

			$PARTITION_UTILITY "/dev/$PARTITION_OPTION"

			whiptail --title 'Disk partitioning' --yesno \
				'Continue partitioning the disks' 0 0

			CONTINUE_PARTITIONING=$?
		done
	fi

	PARTITIONS=$(lsblk -ln | grep 'part' | awk '{print $1" "$1}' | tr '\n' ' ')

	EFI_PARTITION=$(whiptail --title 'Disk partitioning' --nocancel --notags --menu \
		'Select the desired EFI partition' 0 0 0 $PARTITIONS \
		3>&1 1>&2 2>&3)

	whiptail --title 'Disk partitioning' --nocancel --yesno \
		'Do not format EFI partition' 0 0

	FORMAT_EFI_PARTITION=$?

	SWAP_PARTITION=$(whiptail --title 'Disk partitioning' --nocancel --notags --menu \
		'Select the desired swap partition or none for none' 0 0 0 '' 'none' $PARTITIONS \
		3>&1 1>&2 2>&3)

	ROOT_PARTITION=$(whiptail --title 'Disk partitioning' --nocancel --notags --menu \
		'Select the desired root partition' 0 0 0 $PARTITIONS \
		3>&1 1>&2 2>&3)

	LOCALES=$(cat /etc/locale.gen | grep '.UTF-8 UTF-8' | tr -d '#' | awk '{print $1" "$1}' | tr '\n' ' ')

	LOCALE=$(whiptail --title 'Locale' --nocancel --notags --menu \
		'Select the desired locale' 0 0 0 $LOCALES \
		3>&1 1>&2 2>&3)

	ZONES=$(ls -1 /usr/share/zoneinfo | awk '{print $1" "$1}' | tr '\n' ' ')

	ZONE=$(whiptail --title 'Timezone' --nocancel --notags --menu \
		'Select the desired timezone zone' 0 0 0 $ZONES \
		3>&1 1>&2 2>&3)

	SUB_ZONES=$(ls -1 "/usr/share/zoneinfo/$ZONE" | awk '{print $1" "$1}' | tr '\n' ' ')

	SUB_ZONE=$(whiptail --title 'Timezone' --nocancel --notags --menu \
		'Select the desired timezone sub zone' 0 0 0 $SUB_ZONES \
		3>&1 1>&2 2>&3)

	TIMEZONE="$ZONE/$SUB_ZONE"

	HOSTNAME=$(whiptail --title 'Hostname' --nocancel --inputbox \
		'Write the desired hostname' 0 0 \
		3>&1 1>&2 2>&3)

	USERNAME=$(whiptail --title 'User' --nocancel --inputbox \
		'Write the desired user name' 0 0 \
		3>&1 1>&2 2>&3)

	MICROCODE=$(whiptail --title 'Microcode' --nocancel --notags --menu \
		'Select the right microcode for your processor or none for none' 0 0 0 \
		'amd-ucode' 'amd-ucode' \
		'intel-ucode' 'intel-ucode' \
		'' 'none' \
		3>&1 1>&2 2>&3)

	TYPE=$(whiptail --title 'Type' --nocancel --notags --menu \
		'Select the desired installation type' 0 0 0 \
		'base' 'base' \
		'hyprland' 'hyprland' \
		'dwm' 'dwm' \
		3>&1 1>&2 2>&3)

	printf '#!/bin/sh\n' > install-vars.sh
	printf "KEYMAP='$KEYMAP'\n" >> install-vars.sh
	printf "EFI_PARTITION='$EFI_PARTITION'\n" >> install-vars.sh
	printf "FORMAT_EFI_PARTITION='$FORMAT_EFI_PARTITION'\n" >> install-vars.sh
	printf "SWAP_PARTITION='$SWAP_PARTITION'\n" >> install-vars.sh
	printf "ROOT_PARTITION='$ROOT_PARTITION'\n" >> install-vars.sh
	printf "LOCALE='$LOCALE'\n" >> install-vars.sh
	printf "TIMEZONE='$TIMEZONE'\n" >> install-vars.sh
	printf "HOSTNAME='$HOSTNAME'\n" >> install-vars.sh
	printf "USERNAME='$USERNAME'\n" >> install-vars.sh
	printf "MICROCODE='$MICROCODE'\n" >> install-vars.sh
	printf "TYPE='$TYPE'\n" >> install-vars.sh
elif [ "$1" = '--install' ]
then
	. ./install-vars.sh

	loadkeys "$KEYMAP"

	PASSWORD=$(whiptail --title 'User' --nocancel --inputbox \
		'Write the desired user password' 0 0 \
		3>&1 1>&2 2>&3)

	whiptail --title 'User' --msgbox \
		'The password will be used for root user too' 0 0

	umount -R /mnt

	mkfs.ext4 -F "/dev/$ROOT_PARTITION"

	if [ $FORMAT_EFI_PARTITION -eq 1 ]
	then
		mkfs.fat -F 32 "/dev/$EFI_PARTITION"
	fi

	if [ -n "$SWAP_PARTITION" ]
	then
		mkswap "/dev/$SWAP_PARTITION"
	fi

	mount "/dev/$ROOT_PARTITION" /mnt

	mount --mkdir "/dev/$EFI_PARTITION" /mnt/boot

	if [ -n "$SWAP_PARTITION" ]
	then
		swapon "/dev/$SWAP_PARTITION"
	fi

	PACSTRAP_PACKAGES='base linux linux-firmware'

	pacstrap -K /mnt $PACSTRAP_PACKAGES

	genfstab -U /mnt >> /mnt/etc/fstab

	cp $0 /mnt/install-script

	cp ./install-vars.sh /mnt/install-vars

	chmod 777 /mnt/install-script /mnt/install-vars

	printf "PASSWORD='$PASSWORD'\n" >> /mnt/install-vars

	arch-chroot /mnt /install-script root

	rm /mnt/install-script /mnt/install-vars
elif [ "$1" = 'root' ]
then
	. /install-vars

	ln -sf /usr/share/zoneinfo/$TIMEZONE /etc/localtime

	hwclock --systohc

	pacman -S --noconfirm dash

	ln -sfT dash /usr/bin/sh

	HOOK_FILE='/usr/share/libalpm/hooks/shell-relink.hoo'

	printf '[Trigger]\n' > $HOOK_FILE
	printf 'Type = Package\n' >> $HOOK_FILE
	printf 'Operation = Upgrade\n' >> $HOOK_FILE
	printf 'Target = bash\n\n' >> $HOOK_FILE
	printf '[Action]\n' >> $HOOK_FILE
	printf 'Description = Re-pointing /bin/sh to dash...\n' >> $HOOK_FILE
	printf 'When = PostTransaction\n' >> $HOOK_FILE
	printf 'Exec = /usr/bin/ln -sfT dash /usr/bin/sh\n' >> $HOOK_FILE
	printf 'Depends = dash\n'

	printf "KEYMAP=$KEYMAP\n" > /etc/vconsole.conf

	sed -i "s/#$LOCALE/$LOCALE/" /etc/locale.gen

	locale-gen

	printf "LANG=$LOCALE\n" > /etc/locale.conf

	printf "$HOSTNAME\n" > /etc/hostname

	printf '127.0.0.1\tlocalhost\n' > /etc/hosts
	printf '::1\t\tlocalhost\n' >> /etc/hosts
	printf "127.0.1.1\t$HOSTNAME\n" >> /etc/hosts

	pacman -S --noconfirm networkmanager

	systemctl enable NetworkManager.service

	pacman -S --noconfirm sudo

	useradd -m -G wheel "$USERNAME"

	printf '%%wheel ALL=(ALL:ALL) NOPASSWD: ALL # temp\n' >> /etc/sudoers

	printf "root:$PASSWORD\n" | chpasswd
	printf "$USERNAME:$PASSWORD\n" | chpasswd

	pacman -S --noconfirm grub efibootmgr

	grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB

	if [ -n "$MICROCODE" ]
	then
		pacman -S --noconfirm $MICROCODE
	fi

	grub-mkconfig -o /boot/grub/grub.cfg

	FIRMWARE_PACKAGES=''
	DEPENDENCY_PACKAGES=''
	SYSTEM_PACKAGES=''
	FONT_PACKAGES=''
	AUDIO_PACKAGES=''
	USER_PACKAGES=''
	UTIL_PACKAGES=''

	if [ "$TYPE" = 'hyprland' ]
	then
		FIRMWARE_PACKAGES='alsa-firmware sof-firmware'
		DEPENDENCY_PACKAGES='qt5-wayland qt6-wayland gtk4 rustup'
		SYSTEM_PACKAGES='base-devel git openssh starship'
		FONT_PACKAGES='ttf-nerd-fonts-symbols noto-fonts noto-fonts-cjk noto-fonts-emoji'
		AUDIO_PACKAGES='pipewire pipewire-alsa pipewire-audio pipewire-jack pipewire-pulse wireplumber'
		USER_PACKAGES='dunst kitty polkit polkit-gnome udisks2 waybar wofi xdg-desktop-portal xdg-desktop-portal-wlr'
		UTIL_PACKAGES='man-db man-pages neovim texinfo'
	elif [ "$TYPE" = 'dwm' ]
	then
		FIRMWARE_PACKAGES='alsa-firmware sof-firmware'
		DEPENDENCY_PACKAGES='gtk4 libx11 libxft libxinerama rustup'
		SYSTEM_PACKAGES='base-devel git openssh starship xorg-server xorg-xinit'
		FONT_PACKAGES='ttf-nerd-fonts-symbols noto-fonts noto-fonts-cjk noto-fonts-emoji'
		AUDIO_PACKAGES='jack2 pulseaudio pulseaudio-alsa pulseaudio-jack'
		USER_PACKAGES='dunst feh kitty picom polkit polkit-gnome udisks2'
		UTIL_PACKAGES='man-db man-pages neovim texinfo'
	else
		DEPENDENCY_PACKAGES='rustup'
		SYSTEM_PACKAGES='base-devel git'
		UTIL_PACKAGES='neovim'
	fi

	if [ -n "$FIRMWARE_PACKAGES" ]
	then
		pacman -S --noconfirm $FIRMWARE_PACKAGES
	fi

	if [ -n "$DEPENDENCY_PACKAGES" ]
	then
		pacman -S --noconfirm $DEPENDENCY_PACKAGES
	fi

	if [ -n "$SYSTEM_PACKAGES" ]
	then
		pacman -S --noconfirm $SYSTEM_PACKAGES
	fi

	if [ -n "$FONT_PACKAGES" ]
	then
		pacman -S --noconfirm $FONT_PACKAGES
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

	sudo -u "$USERNAME" /install-script user

	sed -i '$d' /etc/sudoers

	printf '%%wheel ALL=(ALL:ALL) ALL\n' >> /etc/sudoers
elif [ "$1" = 'user' ]
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

	. /install-vars

	if [ "$TYPE" = 'dwm' ]
	then
		git clone https://github.com/l0py2/dwm

		git clone https://github.com/l0py2/dmenu

		cd dwm

		make

		sudo make install

		cd ../dmenu

		make

		sudo make install

		cd ..
	fi

	if [ "$TYPE" = 'base' ]
	then
		git clone --separate-git-dir=$HOME/.dotfiles https://github.com/l0py2/dotfiles-base dotfiles
	elif [ "$TYPE" = 'hyprland' ]
	then
		git clone --separate-git-dir=$HOME/.dotfiles https://github.com/l0py2/dotfiles-hyprland dotfiles
	elif [ "$TYPE" = 'dwm' ]
	then
		git clone --separate-git-dir=$HOME/.dotfiles https://github.com/l0py2/dotfiles-dwm dotfiles
	fi

	rm dotfiles/.git

	cp -r dotfiles/. $HOME

	cd $HOME

	rm -rf repositories

	git --git-dir=$HOME/.dotfiles --work-tree=$HOME config status.showUntrackedFiles no

	AUR_PACKAGES=''

	if [ "$TYPE" = 'hyprland' ]
	then
		AUR_PACKAGES='hyprland-git'
	fi

	if [ -n "$AUR_PACKAGES" ]
	then
		paru -S --noconfirm $AUR_PACKAGES
	fi
else
	printf 'Use --help to get help\n'
fi
