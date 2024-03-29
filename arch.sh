#!/bin/sh

whiptail_height=20
whiptail_width=60

pre_installation_log='/root/installation_log.txt'

installation_temp='/installation'
installation_log="$installation_temp/installation_log.txt"
installation_script_location="$installation_temp/install-script"
installation_vars_location="$installation_temp/install-vars"
installation_final='/root/installation'

original_default='/root/original-default'

enable_service() {
	printf "Enabling: $1\n"

	systemctl enable "$1.service" >> "$installation_log" 2>&1
}

install_packages() {
	if [ -n "$1" ]
	then
		printf "Installing packages: $1\n"

		pacman -S --noconfirm $1 >> "$installation_log" 2>&1
	fi
}

clone_dotfiles() {
	printf "Cloning dotfiles: $1\n"

	{
		mkdir -p "$HOME/repositories"

		cd "$HOME/repositories"

		git clone --separate-git-dir="$HOME/.dotfiles" --depth=1 "https://github.com/l0py2/$1" dotfiles

		rm dotfiles/.git

		cp -r dotfiles/. "$HOME"

		git --git-dir="$HOME/.dotfiles" --work-tree="$HOME" config status.showUntrackedFiles no
	} >> "$installation_log" 2>&1
}

make_aur_packages() {
	if [ -n "$1" ]
	then
		printf "Making packages from the AUR: $1\n"

		{
			mkdir -p "$HOME/repositories"

			cd "$HOME/repositories"

			for package in $1
			do
				git clone --depth=1 "https://aur.archlinux.org/$package.git" "$package"

				cd "$package"

				makepkg -si --noconfirm

				cd ..
			done
		} >> "$installation_log" 2>&1
	fi
}

make_repository() {
	printf "Making repository: $1\n"

	{
		mkdir -p "$HOME/repositories"

		cd "$HOME/repositories"

		git clone --depth=1 "$2" "$1"

		cd "$1"

		make
		make install
	} >> "$installation_log" 2>&1
}

sudo_make_repository() {
	printf "Making repository: $1\n"

	{
		mkdir -p "$HOME/repositories"

		cd "$HOME/repositories"

		git clone --depth=1 "$2" "$1"

		cd "$1"

		make
		sudo make install
	} >> "$installation_log" 2>&1
}

whiptail_msgbox() {
	whiptail --title "$1" --msgbox "$2" "$whiptail_height" "$whiptail_width"
}

whiptail_yesno() {
	whiptail --title "$1" --yesno "$2" "$whiptail_height" "$whiptail_width"
}

whiptail_menu() {
	whiptail --title "$1" --nocancel --notags --menu "$2" "$whiptail_height" "$whiptail_width" 0 $3 \
		3>&1 1>&2 2>&3
}

whiptail_checklist() {
	whiptail --title "$1" --nocancel --notags --checklist "$2" "$whiptail_height" "$whiptail_width" 0 $3 \
		3>&1 1>&2 2>&3 | tr -d '"'
}

whiptail_inputbox() {
	whiptail --title "$1" --nocancel --inputbox "$2" "$whiptail_height" "$whiptail_width" 3>&1 1>&2 2>&3
}

whiptail_passwordbox() {
	whiptail --title "$1" --nocancel --passwordbox "$2" "$whiptail_height" "$whiptail_width" 3>&1 1>&2 2>&3
}

if [ ! $1 ] || [ "$1" = '--help' ]
then
	printf 'Automated Arch Linux install script quick guide\n\n'
	printf 'Use --init to start an new configuration\n'
	printf 'Use --install to install based on the current configuration\n'
elif [ "$1" = '--init' ]
then
	efi_system=0

	ls /sys/firmware/efi > /dev/null 2>&1

	if [ $? -eq 0 ]
	then
		efi_system=1
	fi

	whiptail_msgbox 'Arch Linux install script' \
		'Welcome to l0py2 automated Arch install script'

	keymap_list=$(localectl list-keymaps | awk '{print $1" "$1}' | tr '\n' ' ')

	KEYMAP=$(whiptail_menu 'Keymap' 'Select the desired keymap' "$keymap_list")

	loadkeys "$KEYMAP"

	disk_list=$(lsblk -ln | grep 'disk' | awk '{print $1" "$1}' | tr '\n' ' ')

	whiptail_yesno 'Disk partitioning' \
		'Have you already partitioned the desired partitions for the installation'

	if [ $? -eq 1 ]
	then
		partition_utility=$(whiptail_menu 'Disk partitioning' \
			'Select fdisk or cfdisk for partitioning' \
			'fdisk fdisk cfdisk cfdisk')

		continue_partitioning=0

		while [ $continue_partitioning -eq 0 ]
		do
			partition_option=$(whiptail_menu 'Disk partitioning' \
				'Select the desired disk to partition' "$disk_list")

			$partition_utility "/dev/$partition_option"

			whiptail_yesno 'Disk partitioning' \
				'Continue partitioning the disks'

			continue_partitioning=$?
		done
	fi

	partition_list=$(lsblk -ln | grep 'part' | awk '{print $1" "$1}' | tr '\n' ' ')

	if [ $efi_system -eq 1 ]
	then
		EFI_PARTITION=$(whiptail_menu 'Disk partitioning' \
			'Select the desired EFI partition' "$partition_list")

		whiptail_yesno 'Disk partitioning' 'Do not format EFI partition'

		FORMAT_EFI_PARTITION=$?
	else
		BIOS_DISK=$(whiptail_menu 'Disk partitioning' \
			'Select the disk that contains the desired BIOS boot partition' \
			"$disk_list")
	fi

	SWAP_PARTITION=$(whiptail_menu 'Disk partitioning' \
		'Select the desired swap partition or none for none' "none none $partition_list")

	ROOT_PARTITION=$(whiptail_menu 'Disk partitioning' \
		'Select the desired root partition' "$partition_list")

	locale_list=$(cat /etc/locale.gen | grep '.UTF-8 UTF-8' | tr -d '#' | awk '{print $1" "$1}' | tr '\n' ' ')

	LOCALE=$(whiptail_menu 'Locale' 'Select the desired locale' "$locale_list")

	zone_list=$(ls -1 /usr/share/zoneinfo | awk '{print $1" "$1}' | tr '\n' ' ')

	zone=$(whiptail_menu 'Timezone' 'Select the desired timezone zone' \
		"$zone_list")

	if [ -d "/usr/share/zoneinfo/$zone" ]
	then
		sub_zone_list=$(ls -1 "/usr/share/zoneinfo/$zone" | awk '{print $1" "$1}' | tr '\n' ' ')

		sub_zone=$(whiptail_menu 'Timezone' 'Select the desired timezone sub zone' \
			"$sub_zone_list")
	fi

	TIMEZONE="$zone/$sub_zone"

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

	whiptail_yesno 'Additional packages' 'Install Arch User Repository (AUR) helper'
	INSTALL_AUR_HELPER=$?

	vars_file='install-vars.sh'
	printf '#!/bin/sh\n' > $vars_file
	printf "KEYMAP='$KEYMAP'\n" >> $vars_file
	printf "BIOS_DISK='$BIOS_DISK'\n" >> $vars_file
	printf "EFI_PARTITION='$EFI_PARTITION'\n" >> $vars_file
	printf "FORMAT_EFI_PARTITION='$FORMAT_EFI_PARTITION'\n" >> $vars_file
	printf "SWAP_PARTITION='$SWAP_PARTITION'\n" >> $vars_file
	printf "ROOT_PARTITION='$ROOT_PARTITION'\n" >> $vars_file
	printf "LOCALE='$LOCALE'\n" >> $vars_file
	printf "TIMEZONE='$TIMEZONE'\n" >> $vars_file
	printf "HOSTNAME='$HOSTNAME'\n" >> $vars_file
	printf "USERNAME='$USERNAME'\n" >> $vars_file
	printf "KERNEL='$KERNEL'\n" >> $vars_file
	printf "MICROCODE='$MICROCODE'\n" >> $vars_file
	printf "TYPE='$TYPE'\n" >> $vars_file
	printf "ADDITIONAL_PACKAGES='$ADDITIONAL_PACKAGES'\n" >> $vars_file
	printf "INSTALL_AUR_HELPER='$INSTALL_AUR_HELPER'\n" >> $vars_file
elif [ "$1" = '--install' ]
then
	. ./install-vars.sh

	touch "$pre_installation_log"

	loadkeys "$KEYMAP"

	PASSWORD=$(whiptail_passwordbox 'User' 'Write the desired user password')

	verification_password=$(whiptail_passwordbox 'User' 'Write the desired user password again to confirm')

	while [ ! "$PASSWORD" = "$verification_password" ]
	do
		whiptail_msgbox 'User' 'Passwords do not match'

		PASSWORD=$(whiptail_passwordbox 'User' 'Write the desired user password')

		verification_password=$(whiptail_passwordbox 'User' 'Write the desired user password again to confirm')
	done

	whiptail_msgbox 'User' 'The password will be used for root user too'

	printf 'Formatting and mounting partitions\n'

	{
		umount -R /mnt

		mkfs.ext4 -F "/dev/$ROOT_PARTITION"

		mount "/dev/$ROOT_PARTITION" /mnt

		if [ -z "$BIOS_DISK" ]
		then
			if [ $FORMAT_EFI_PARTITION -eq 1 ]
			then
				mkfs.fat -F 32 "/dev/$EFI_PARTITION"
			fi

			mount --mkdir "/dev/$EFI_PARTITION" /mnt/boot
		fi

		if [ "$SWAP_PARTITION" != 'none' ]
		then
			mkswap "/dev/$SWAP_PARTITION"

			swapon "/dev/$SWAP_PARTITION"
		fi
	} >> "$pre_installation_log" 2>&1

	pacstrap_packages="base $KERNEL linux-firmware"

	printf "Installing base system: $pacstrap_packages\n"

	{
		pacstrap -K /mnt $pacstrap_packages

		genfstab -U /mnt >> /mnt/etc/fstab

		localectl set-keymap "$KEYMAP"

		cp /etc/vconsole.conf /mnt/etc/vconsole.conf
		mkdir -p /mnt/etc/X11/xorg.conf.d
		cp /etc/X11/xorg.conf.d/00-keyboard.conf /mnt/etc/X11/xorg.conf.d/00-keyboard.conf

		mkdir -p "/mnt$installation_temp"
		mkdir -p "/mnt$original_default"

		cp $0 "/mnt$installation_script_location"
		cp ./install-vars.sh "/mnt$installation_vars_location"
		cp "$pre_installation_log" "/mnt$installation_log"

		chmod 777 "/mnt$installation_temp" "/mnt$original_default" "/mnt$installation_script_location" "/mnt$installation_vars_location"
		chmod 666 "/mnt$installation_log"

		printf "PASSWORD='$PASSWORD'\n" >> "/mnt$installation_vars_location"
	} >> "$pre_installation_log" 2>&1

	arch-chroot /mnt "$installation_script_location" root

	printf 'The installation is complete\n'
elif [ "$1" = 'root' ]
then
	. "$installation_vars_location"

	{
		ln -sf /usr/share/zoneinfo/$TIMEZONE /etc/localtime

		hwclock --systohc
	} >> "$installation_log" 2>&1

	install_packages 'dash'

	{
		ln -sfT dash /usr/bin/sh

		SHELL_HOOK_FILE='/usr/share/libalpm/hooks/shell-relink.hook'
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

		locale-gen

		printf "LANG=$LOCALE\n" > /etc/locale.conf

		printf "$HOSTNAME\n" > /etc/hostname

		HOSTS_FILE='/etc/hosts'
		cat << EOF > $HOSTS_FILE
127.0.0.1	localhost
::1		localhost
127.0.1.1	$HOSTNAME
EOF
	} >> "$installation_log" 2>&1

	install_packages 'networkmanager'

	enable_service 'NetworkManager'

	install_packages 'git'

	{
		cp -r /etc/skel "$original_default"
		cd /etc/skel
		git clone --depth=1 https://github.com/l0py2/dotfiles-base
		rm -rf dotfiles-base/.git
		cp -r dotfiles-base/. ./
		rm -r dotfiles-base
		cp -r ./ /root
	} >> "$installation_log" 2>&1

	install_packages 'sudo'

	sudoers_file='/etc/sudoers'

	{
		useradd -m -G wheel "$USERNAME"

		cp $sudoers_file "$original_default"

		printf '%%wheel ALL=(ALL:ALL) NOPASSWD: ALL # temp\n' >> $sudoers_file

		printf "root:$PASSWORD\n" | chpasswd
		printf "$USERNAME:$PASSWORD\n" | chpasswd
	} >> "$installation_log" 2>&1

	install_packages 'grub'

	if [ -z "$BIOS_DISK" ]
	then
		install_packages 'efibootmgr'

		grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB >> "$installation_log" 2>&1
	else
		grub-install --target=i386-pc "/dev/$BIOS_DISK" >> "$installation_log" 2>&1
	fi

	if [ "$MICROCODE" != 'none' ]
	then
		install_packages "$MICROCODE"
	fi

	grub-mkconfig -o /boot/grub/grub.cfg >> "$installation_log" 2>&1

	sudo -u "$USERNAME" "$installation_script_location" dotfiles

	firmware_packages='alsa-firmware sof-firmware'
	dependency_packages='rustup'
	font_packages='noto-fonts noto-fonts-cjk'
	audio_packages=''
	system_packages='base-devel openssh'
	user_packages='neovim'
	util_packages='man-db man-pages texinfo'

	if [ "$TYPE" = 'hyprland' ]
	then
		dependency_packages="$dependency_packages qt5-wayland qt6-wayland gtk4"
		font_packages="$font_packages noto-fonts-emoji ttf-nerd-fonts-symbols"
		audio_packages="$audio_packages pipewire pipewire-alsa pipewire-audio pipewire-jack pipewire-pulse wireplumber pavucontrol"
		system_packages="$system_packages polkit polkit-gnome xdg-desktop-portal-wlr xdg-user-dirs"
		user_packages="$user_packages starship dunst kitty swaybg thunar udisks2 waybar wofi"
	elif [ "$TYPE" = 'dwm' ]
	then
		dependency_packages="$dependency_packages libx11 libxft libxinerama"
		font_packages="$font_packages noto-fonts-emoji ttf-nerd-fonts-symbols"
		audio_packages="$audio_packages pipewire pipewire-alsa pipewire-audio pipewire-jack pipewire-pulse wireplumber pavucontrol"
		system_packages="$system_packages polkit polkit-gnome xdg-desktop-portal-gtk xdg-user-dirs xorg-server xorg-xinit xss-lock"
		user_packages="$user_packages dunst feh picom thunar thunar-archive-plugin udisks2 xarchiver"
		util_packages="$util_packages acpi rclone"
	elif [ "$TYPE" = 'xfce' ]
	then
		font_packages="$font_packages noto-fonts-emoji"
		audio_packages="$audio_packages pipewire pipewire-alsa pipewire-audio pipewire-jack pipewire-pulse wireplumber"
		system_packages="$system_packages lightdm lightdm-gtk-greeter xfce4 xfce4-goodies"
		user_packages="$user_packages pavucontrol xarchiver"
	fi

	install_packages "$firmware_packages"
	install_packages "$dependency_packages"
	install_packages "$font_packages"
	install_packages "$audio_packages"
	install_packages "$system_packages"
	install_packages "$user_packages"
	install_packages "$util_packages"
	install_packages "$ADDITIONAL_PACKAGES"

	if [ "$TYPE" = 'xfce' ]
	then
		enable_service 'lightdm'
	fi

	sudo -u "$USERNAME" "$installation_script_location" user

	cat << EOF > $sudoers_file
# The default sudoers file is located in the $original_default directory
root ALL=(ALL:ALL) ALL

%wheel ALL=(ALL:ALL) ALL

@includedir /etc/sudoers.d
EOF

	cp -r "$installation_temp/." "$installation_final"
	rm -rf "$installation_temp"
elif [ "$1" = 'dotfiles' ]
then
	. "$installation_vars_location"

	if [ "$TYPE" = 'hyprland' ]
	then
		clone_dotfiles 'dotfiles-hyprland'
	elif [ "$TYPE" = 'dwm' ]
	then
		clone_dotfiles 'dotfiles-dwm'
	fi
elif [ "$1" = 'user' ]
then
	. "$installation_vars_location"

	rustup default stable >> "$installation_log" 2>&1

	if [ "$INSTALL_AUR_HELPER" -eq 0 ]
	then
		make_aur_packages 'paru'

		paru --gendb >> "$installation_log" 2>&1
	fi

	if [ "$TYPE" = 'dwm' ] || [ "$TYPE" = 'hyprland' ]
	then
		xdg-user-dirs-update >> "$installation_log" 2>&1
	fi

	if [ "$TYPE" = 'dwm' ]
	then
		make_repository 'dmenu-scripts' 'https://github.com/l0py2/dmenu-scripts'
		make_repository 'scripts' 'https://github.com/l0py2/scripts'

		sudo_make_repository 'dwm' 'https://github.com/l0py2/dwm'
		sudo_make_repository 'dmenu' 'https://github.com/l0py2/dmenu'
		sudo_make_repository 'dwmblocks' 'https://github.com/l0py2/dwmblocks'
		sudo_make_repository 'st' 'https://github.com/l0py2/st'
		sudo_make_repository 'slock' 'https://github.com/l0py2/slock'
	fi

	aur_packages=''

	if [ "$TYPE" = 'hyprland' ]
	then
		aur_packages="$aur_packages hyprland-git"
	fi

	make_aur_packages "$aur_packages"

	rm -rf "$HOME/repositories"
else
	printf 'Use --help to get help\n'
fi
