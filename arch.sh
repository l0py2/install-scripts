#!/bin/sh

VARS_FILE='install-vars.sh'

SHELL_HOOK_FILE='/usr/share/libalpm/hooks/shell-relink.hook'
HOSTS_FILE='/etc/hosts'
SUDOERS_FILE='/etc/sudoers'

FIRMWARE_PACKAGES=''
DEPENDENCY_PACKAGES=''
SYSTEM_PACKAGES=''
FONT_PACKAGES=''
AUDIO_PACKAGES=''
USER_PACKAGES=''
UTIL_PACKAGES=''
AUR_PACKAGES=''

enable_service() {
	printf "Enabling: $1\n"

	systemctl enable $1.service >> /dev/null
}

install_packages() {
	if [ -n "$1" ]
	then
		printf "Installing: $1\n"

		pacman -S --noconfirm $1 >> /dev/null
	fi
}

install_packages_aur() {
	if [ -n "$1" ]
	then
		printf "Installing: $1\n"

		paru -S --noconfirm $1 >> /dev/null
	fi
}

clone_repository() {
	printf "Cloning: $1\n"

	git clone $1 >> /dev/null
}

clone_dotfiles() {
	git clone --separate-git-dir=$HOME/.dotfiles https://github.com/l0py2/$1 dotfiles >> /dev/null

	rm dotfiles/.git

	cp -r dotfiles/. $HOME

	git --git-dir=$HOME/.dotfiles --work-tree=$HOME config status.showUntrackedFiles no >> /dev/null
}

whiptail_msgbox() {
	whiptail --title "$1" --msgbox "$2" 0 0
}

whiptail_yesno() {
	whiptail --title "$1" --yesno "$2" 0 0
}

whiptail_menu() {
	whiptail --title "$1" --nocancel --notags --menu "$2" 0 0 0 $3 \
		3>&1 1>&2 2>&3
}

whiptail_checklist() {
	whiptail --title "$1" --nocancel --notags --checklist "$2" 0 0 0 $3 \
		3>&1 1>&2 2>&3 | tr -d '"'
}

whiptail_inputbox() {
	whiptail --title "$1" --nocancel --inputbox "$2" 0 0 3>&1 1>&2 2>&3
}

if [ ! $1 ] || [ "$1" = '--help' ]
then
	printf 'Automated Arch Linux install script quick guide\n\n'
	printf 'Use --init to start an new configuration\n'
	printf 'Use --install to install based on the current configuration\n'
elif [ "$1" = '--init' ]
then
	EFI_SYSTEM=0

	ls /sys/firmware/efi > /dev/null 2>&1

	if [ $? -eq 0 ]
	then
		EFI_SYSTEM=1
	fi

	whiptail_msgbox 'Arch Linux install script' \
		'Welcome to l0py2 automated Arch install script'

	KEYMAPS=$(localectl list-keymaps | awk '{print $1" "$1}' | tr '\n' ' ')

	KEYMAP=$(whiptail_menu 'Keymap' 'Select the desired keymap' "$KEYMAPS")

	loadkeys "$KEYMAP"

	DISKS=$(lsblk -ln | grep 'disk' | awk '{print $1" "$1}' | tr '\n' ' ')

	whiptail_yesno 'Disk partitioning' \
		'Have you already partitioned the desired partitions for the installation'

	if [ $? -eq 1 ]
	then
		PARTITION_UTILITY=$(whiptail_menu 'Disk partitioning' \
			'Select fdisk or cfdisk for partitioning' \
			'fdisk fdisk cfdisk cfdisk')

		CONTINUE_PARTITIONING=0

		while [ $CONTINUE_PARTITIONING -eq 0 ]
		do
			PARTITION_OPTION=$(whiptail_menu 'Disk partitioning' \
				'Select the desired disk to partition' "$DISKS")

			$PARTITION_UTILITY "/dev/$PARTITION_OPTION"

			whiptail_yesno 'Disk partitioning' \
				'Continue partitioning the disks'

			CONTINUE_PARTITIONING=$?
		done
	fi

	PARTITIONS=$(lsblk -ln | grep 'part' | awk '{print $1" "$1}' | tr '\n' ' ')

	if [ $EFI_SYSTEM -eq 1 ]
	then
		EFI_PARTITION=$(whiptail_menu 'Disk partitioning' \
			'Select the desired EFI partition' "$PARTITIONS")

		whiptail_yesno 'Disk partitioning' 'Do not format EFI partition'

		FORMAT_EFI_PARTITION=$?
	else
		BIOS_DISK=$(whiptail_menu 'Disk partitioning' \
			'Select the disk that contains the desired BIOS boot partition' \
			"$DISKS")
	fi

	SWAP_PARTITION=$(whiptail_menu 'Disk partitioning' \
		'Select the desired swap partition or none for none' "none none $PARTITIONS")

	ROOT_PARTITION=$(whiptail_menu 'Disk partitioning' \
		'Select the desired root partition' "$PARTITIONS")

	LOCALES=$(cat /etc/locale.gen | grep '.UTF-8 UTF-8' | tr -d '#' | awk '{print $1" "$1}' | tr '\n' ' ')

	LOCALE=$(whiptail_menu 'Locale' 'Select the desired locale' "$LOCALES")

	ZONES=$(ls -1 /usr/share/zoneinfo | awk '{print $1" "$1}' | tr '\n' ' ')

	ZONE=$(whiptail_menu 'Timezone' 'Select the desired timezone zone' \
		"$ZONES")

	if [ -d "/usr/share/zoneinfo/$ZONE" ]
	then
		SUB_ZONES=$(ls -1 "/usr/share/zoneinfo/$ZONE" | awk '{print $1" "$1}' | tr '\n' ' ')

		SUB_ZONE=$(whiptail_menu 'Timezone' 'Select the desired timezone sub zone' \
			"$SUB_ZONES")
	fi

	TIMEZONE="$ZONE/$SUB_ZONE"

	HOSTNAME=$(whiptail_inputbox 'Hostname' 'Write the desired hostname')

	USERNAME=$(whiptail_inputbox 'User' 'Write the desired user name')

	KERNEL=''

	while [ -z "$KERNEL" ]
	do
		KERNEL=$(whiptail_checklist 'Kernel' \
			'Select at least one kernel' \
			'linux linux on linux-zen linux-zen off')
	done

	MICROCODE=$(whiptail_menu 'Microcode' \
		'Select the right microcode for your processor or none for none' \
		'amd-ucode amd-ucode intel-ucode intel-ucode none none')

	TYPE=$(whiptail_menu 'Type' 'Select the desired installation type' \
		'base base hyprland hyprland dwm dwm xfce xfce')

	ADDITIONAL_PACKAGES=$(whiptail_inputbox 'Additional packages' \
		'Write the names of additional packages separated by spaces')

	printf '#!/bin/sh\n' > $VARS_FILE
	printf "KEYMAP='$KEYMAP'\n" >> $VARS_FILE
	printf "BIOS_DISK='$BIOS_DISK'\n" >> $VARS_FILE
	printf "EFI_PARTITION='$EFI_PARTITION'\n" >> $VARS_FILE
	printf "FORMAT_EFI_PARTITION='$FORMAT_EFI_PARTITION'\n" >> $VARS_FILE
	printf "SWAP_PARTITION='$SWAP_PARTITION'\n" >> $VARS_FILE
	printf "ROOT_PARTITION='$ROOT_PARTITION'\n" >> $VARS_FILE
	printf "LOCALE='$LOCALE'\n" >> $VARS_FILE
	printf "TIMEZONE='$TIMEZONE'\n" >> $VARS_FILE
	printf "HOSTNAME='$HOSTNAME'\n" >> $VARS_FILE
	printf "USERNAME='$USERNAME'\n" >> $VARS_FILE
	printf "KERNEL='$KERNEL'\n" >> $VARS_FILE
	printf "MICROCODE='$MICROCODE'\n" >> $VARS_FILE
	printf "TYPE='$TYPE'\n" >> $VARS_FILE
	printf "ADDITIONAL_PACKAGES='$ADDITIONAL_PACKAGES'\n" >> $VARS_FILE
elif [ "$1" = '--install' ]
then
	. ./install-vars.sh

	loadkeys "$KEYMAP"

	PASSWORD=$(whiptail_inputbox 'User' 'Write the desired user password')

	whiptail_msgbox 'User' 'The password will be used for root user too'

	printf 'Formatting and mounting partitions\n'

	umount -R /mnt >> /dev/null

	mkfs.ext4 -F "/dev/$ROOT_PARTITION" >> /dev/null

	mount "/dev/$ROOT_PARTITION" /mnt

	if [ -z "$BIOS_DISK" ]
	then
		if [ $FORMAT_EFI_PARTITION -eq 1 ]
		then
			mkfs.fat -F 32 "/dev/$EFI_PARTITION" >> /dev/null
		fi

		mount --mkdir "/dev/$EFI_PARTITION" /mnt/boot >> /dev/null
	fi

	if [ "$SWAP_PARTITION" != 'none' ]
	then
		mkswap "/dev/$SWAP_PARTITION" >> /dev/null

		swapon "/dev/$SWAP_PARTITION" >> /dev/null
	fi

	printf 'Installing base system\n'

	PACSTRAP_PACKAGES="base $KERNEL linux-firmware"

	pacstrap -K /mnt $PACSTRAP_PACKAGES >> /dev/null

	genfstab -U /mnt >> /mnt/etc/fstab

	localectl set-keymap "$KEYMAP" >> /dev/null

	cp /etc/vconsole.conf /mnt/etc/vconsole.conf
	mkdir -p /mnt/etc/X11/xorg.conf.d
	cp /etc/X11/xorg.conf.d/00-keyboard.conf /mnt/etc/X11/xorg.conf.d/00-keyboard.conf

	cp $0 /mnt/install-script

	cp ./install-vars.sh /mnt/install-vars

	chmod 777 /mnt/install-script /mnt/install-vars

	printf "PASSWORD='$PASSWORD'\n" >> /mnt/install-vars

	arch-chroot /mnt /install-script root

	rm /mnt/install-script /mnt/install-vars

	printf 'The installation is complete\n'
elif [ "$1" = 'root' ]
then
	. /install-vars

	ln -sf /usr/share/zoneinfo/$TIMEZONE /etc/localtime

	hwclock --systohc

	install_packages 'dash'

	ln -sfT dash /usr/bin/sh

	printf '[Trigger]\n' > $SHELL_HOOK_FILE
	printf 'Type = Package\n' >> $SHELL_HOOK_FILE
	printf 'Operation = Upgrade\n' >> $SHELL_HOOK_FILE
	printf 'Target = bash\n\n' >> $SHELL_HOOK_FILE
	printf '[Action]\n' >> $SHELL_HOOK_FILE
	printf 'Description = Re-pointing /bin/sh to dash...\n' >> $SHELL_HOOK_FILE
	printf 'When = PostTransaction\n' >> $SHELL_HOOK_FILE
	printf 'Exec = /usr/bin/ln -sfT dash /usr/bin/sh\n' >> $SHELL_HOOK_FILE
	printf 'Depends = dash\n' >> $SHELL_HOOK_FILE

	sed -i "s/#$LOCALE/$LOCALE/" /etc/locale.gen

	locale-gen >> /dev/null

	printf "LANG=$LOCALE\n" > /etc/locale.conf

	printf "$HOSTNAME\n" > /etc/hostname

	printf '127.0.0.1\tlocalhost\n' > $HOSTS_FILE
	printf '::1\t\tlocalhost\n' >> $HOSTS_FILE
	printf "127.0.1.1\t$HOSTNAME\n" >> $HOSTS_FILE

	install_packages 'networkmanager'

	enable_service 'NetworkManager'

	install_packages 'sudo'

	useradd -m -G wheel "$USERNAME"

	cp $SUDOERS_FILE /etc/default/sudoers

	printf '%%wheel ALL=(ALL:ALL) NOPASSWD: ALL # temp\n' >> $SUDOERS_FILE

	printf "root:$PASSWORD\n" | chpasswd
	printf "$USERNAME:$PASSWORD\n" | chpasswd

	install_packages 'grub'

	if [ -z "$BIOS_DISK" ]
	then
		install_packages 'efibootmgr'

		grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB >> /dev/null
	else
		grub-install --target=i386-pc "/dev/$BIOS_DISK" >> /dev/null
	fi

	if [ "$MICROCODE" != 'none' ]
	then
		install_packages "$MICROCODE"
	fi

	grub-mkconfig -o /boot/grub/grub.cfg >> /dev/null

	FIRMWARE_PACKAGES='alsa-firmware sof-firmware'
	DEPENDENCY_PACKAGES='rustup'
	SYSTEM_PACKAGES='base-devel git openssh'
	UTIL_PACKAGES='neovim'

	if [ "$TYPE" = 'hyprland' ]
	then
		DEPENDENCY_PACKAGES="$DEPENDENCY_PACKAGES qt5-wayland qt6-wayland gtk4"
		FONT_PACKAGES='ttf-nerd-fonts-symbols noto-fonts noto-fonts-cjk noto-fonts-emoji'
		AUDIO_PACKAGES='pipewire pipewire-alsa pipewire-audio pipewire-jack pipewire-pulse wireplumber'
		USER_PACKAGES='starship dunst kitty polkit polkit-gnome swaybg thunar udisks2 waybar wofi xdg-desktop-portal-wlr xdg-user-dirs'
		UTIL_PACKAGES="$UTIL_PACKAGES man-db man-pages texinfo"
	elif [ "$TYPE" = 'dwm' ]
	then
		DEPENDENCY_PACKAGES="$DEPENDENCY_PACKAGES gtk4 libx11 libxft libxinerama"
		SYSTEM_PACKAGES="$STSTEM_PACKAGES xorg-server xorg-xinit"
		FONT_PACKAGES='ttf-nerd-fonts-symbols noto-fonts noto-fonts-cjk noto-fonts-emoji'
		AUDIO_PACKAGES='pipewire pipewire-alsa pipewire-audio pipewire-jack pipewire-pulse wireplumber'
		USER_PACKAGES='starship dunst feh kitty picom polkit polkit-gnome thunar udisks2 xdg-desktop-portal-gtk xdg-user-dirs'
		UTIL_PACKAGES="$UTIL_PACKAGES man-db man-pages texinfo acpi"
	elif [ "$TYPE" = 'xfce' ]
	then
		DEPENDENCY_PACKAGES="$DEPENDENCY_PACKAGES gtk4"
		SYSTEM_PACKAGES="$SYSTEM_PACKAGES lightdm lightdm-gtk-greeter xfce4 xfce4-goodies"
		FONT_PACKAGES='ttf-nerd-fonts-symbols noto-fonts noto-fonts-cjk noto-fonts-emoji'
		AUDIO_PACKAGES='pipewire pipewire-alsa pipewire-audio pipewire-jack pipewire-pulse wireplumber'
		USER_PACKAGES='pavucontrol'
		UTIL_PACKAGES="$UTIL_PACKAGES man-db man-pages texinfo"
	fi

	install_packages "$FIRMWARE_PACKAGES"
	install_packages "$DEPENDENCY_PACKAGES"
	install_packages "$SYSTEM_PACKAGES"
	install_packages "$FONT_PACKAGES"
	install_packages "$AUDIO_PACKAGES"
	install_packages "$USER_PACKAGES"
	install_packages "$UTIL_PACKAGES"

	install_packages "$ADDITIONAL_PACKAGES"

	if [ "$TYPE" = 'xfce' ]
	then
		enable_service 'lightdm'
	fi

	sudo -u "$USERNAME" /install-script user

	cat << EOF > $SUDOERS_FILE
# The default sudoers file is located in the /etc/default directory
root ALL=(ALL:ALL) ALL

%wheel ALL=(ALL:ALL) ALL

@includedir /etc/sudoers.d
EOF

elif [ "$1" = 'user' ]
then
	cd $HOME

	mkdir repositories

	cd repositories

	if [ "$TYPE" = 'hyprland' ]
	then
		clone_dotfiles 'dotfiles-hyprland'
	elif [ "$TYPE" = 'dwm' ]
	then
		clone_dotfiles 'dotfiles-dwm'
	else
		clone_dotfiles 'dotfiles-base'
	fi

	rustup default stable >> /dev/null

	printf 'Installing Paru\n'

	clone_repository 'https://aur.archlinux.org/paru.git'

	cd paru

	makepkg -si --noconfirm >> /dev/null

	paru --gendb >> /dev/null

	cd ..

	. /install-vars

	if [ "$TYPE" = 'dwm' ] || [ "$TYPE" = 'hyprland' ] || [ "$TYPE" = 'xfce' ]
	then
		xdg-user-dirs-update
	fi

	if [ "$TYPE" = 'dwm' ]
	then
		clone_repository 'https://github.com/l0py2/dwm'
		clone_repository 'https://github.com/l0py2/dmenu'
		clone_repository 'https://github.com/l0py2/dmenu-scripts'
		clone_repository 'https://github.com/l0py2/scripts'
		clone_repository 'https://github.com/l0py2/dwmblocks'

		cd dwm
		make >> /dev/null
		sudo make install >> /dev/null

		cd ../dmenu
		make >> /dev/null
		sudo make install >> /dev/null

		cd ../dmenu-scripts
		make install >> /dev/null

		cd ../scripts
		make install >> /dev/null

		cd ../dwmblocks
		make >> /dev/null
		sudo make install >> /dev/null
	fi

	cd $HOME

	rm -rf repositories

	if [ "$TYPE" = 'hyprland' ]
	then
		AUR_PACKAGES='hyprland-git'
	fi

	install_packages_aur "$AUR_PACKAGES"
else
	printf 'Use --help to get help\n'
fi
