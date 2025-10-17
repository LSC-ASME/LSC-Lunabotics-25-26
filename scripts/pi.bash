#!/bin/bash
INTERFACE=$(ls /sys/class/ieee80211/*/device/net)

email() {
	read -rp $"Enter your LSC Email: " lscemail

	while [[ $lscemail != *"@my.lonestar.edu" ]]; do
		echo "Invalid Email! Try Again"
		sleep 2
		read -rp $"Enter your LSC Email: " lscemail
	done

	read -rp $"Enter your LSC Password: " lscpassword
	cat <<EOF
LSC Email: $lscemail
LSC Password: $lscpassword
EOF

	prompt=""
	read -rp "Is this info correct? (Y/N): " prompt
	while [[ $prompt == "" ]]; do
		read -rp $"Is this info correct? (Y/N) " prompt
	done
	case $prompt in
	[Yy]*) ;;
	[Nn]*)
		email
		;;
	esac
}

extra() {
	systemctl disable systemd-networkd-wait-online.service
	systemctl mask systemd-networkd-wait-online.service
}

home_network() {
	prompt=""
	read -rp $"Do you want to setup your Wi-Fi network? (Y/N): " prompt
	while [[ $prompt == "" ]]; do
		read -rp $"Do you want to setup your Wi-Fi network? (Y/N): " prompt
	done

	case $prompt in
	[Yy]*) ;;
	[Nn]*)
		echo "Skipping Home Network Configuration..." && return 0
		;;
	esac

	read -rp $"What is the SSID (network name) for your home network? " ssid
	read -rp $"Type down the password for your network, $ssid: " home_pwd
	cat <<EOF
SSID: $ssid
Password: $home_pwd
EOF
	prompt=""
	read -rp $"Is this info correct? (Y/N): " prompt
	while [[ $prompt == "" ]]; do
		read -rp $"Is this info correct? (Y/N): " prompt
	done

	case $prompt in
	[Yy]*) ;;
	[Nn]*)
		echo "Retrying Home Network Configuration..." && home_network
		;;
	esac

	cat >>/etc/wpa_supplicant/wpa_supplicant-"$INTERFACE".conf <<EOL
network={
	ssid="$ssid"
	psk="$home_pwd"
	key_mgmt=WPA-PSK
}
EOL
}

wifi() {
	echo "Starting LSC Network Configuration..."
	touch /etc/wpa_supplicant/wpa_supplicant-"$INTERFACE".conf
	cat >>/etc/wpa_supplicant/wpa_supplicant-"$INTERFACE".conf <<EOL
network={
	ssid="LoneStar"
	key_mgmt=WPA-EAP
	identity="$lscemail"
	password="$lscpassword"
	eap=PEAP
	phase2="auth=MSCHAPV2"
}
EOL
	echo "Starting wpa_supplicant service..."
	sudo systemctl enable wpa_supplicant@"$INTERFACE"
	sudo systemctl restart wpa_supplicant@"$INTERFACE"

	echo "Starting dhclient executable..."
	sudo dhclient

	echo "Checking if DHCP has begun..."
	dhcp_check=$(hostname -I)
	while [[ $dhcp_check == "" ]]; do
		echo "Waiting for DHCP to load..."
		sleep 3
		dhcp_check=$(hostname -I)
	done

	echo "Installing dhcpcd..."
	sudo apt install -y dhcpcd5

	echo "Uninstalling dhclient..."
	sudo apt autopurge -y isc-dhcp-client

	echo "Enabling and Starting dhcpcd service..."
	sudo systemctl enable dhcpcd && sudo service dhcpcd start
}

ssh() {
	ssh_file=/etc/ssh/sshd_config.d/50-cloud-init.conf

	echo "Enabling Password Authentication on $ssh_file"

	cat >$ssh_file <<EOF
PasswordAuthentication yes
EOF

	echo "Restarting sshd..."
	sudo systemctl restart ssh
}

ros() {
	echo "Updating and Upgrading Services"
	sudo apt update && sudo apt -y upgrade

	echo "Installing necessary applications..."
	sudo apt install -y curl build-essential perl make bzip2

	echo "Updating Locales"
	sudo locale-gen en_US en_US.UTF-8
	export LANG=en_US.UTF-8
	cat >/etc/locale.conf <<EOF
LANG=en_US.UTF-8
LC_COLLATE="C.UTF-8"
EOF

	echo "Adding repository 'universe'..."
	sudo add-apt-repository universe -y

	echo "Creating GPG Key for ROS"
	sudo curl -sSL https://raw.githubusercontent.com/ros/rosdistro/master/ros.key -o /usr/share/keyrings/ros-archive-keyring.gpg

	echo "Adding ROS Repository to sources.list..."
	echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/ros-archive-keyring.gpg] http://packages.ros.org/ros2/ubuntu $(. /etc/os-release && echo "$UBUNTU_CODENAME") main" | sudo tee /etc/apt/sources.list.d/ros2.list >/dev/null

	echo "Updating Repository with apt..."
	sudo apt update -y

	echo "Installing ROS 2 Humble"
	sudo apt install -y ros-humble-ros-base ros-dev-tools ros-humble-desktop

	echo "Configuring ~/.bashrc"
	cat >>~/.bashrc <<EOL
source /opt/ros/humble/setup.bash"
EOL

	bash

	cat <<EOF
Installation Finished...
If you want to SSH into your Raspberry Pi, the IP is: $dhcp_check
EOF
}

email
home_network
wifi
ssh
extra
ros
