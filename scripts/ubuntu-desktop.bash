#!/bin/bash
CHECK=$(lsmod | grep -c vboxvideo)

post() {
	sudo apt -y update && sudo apt -y upgrade 

	sudo add-apt-repository -y universe 
	
	sudo curl -sSL https://raw.githubusercontent.com/ros/rosdistro/master/ros.key -o /usr/share/keyrings/ros-archive-keyring.gpg 

	echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/ros-archive-keyring.gpg] http://packages.ros.org/ros2/ubuntu $(. /etc/os-release && echo $UBUNTU_CODENAME) main" | sudo tee /etc/apt/sources.list.d/ros2.list > /dev/null 

	sudo apt -y update && sudo apt -y upgrade 
s
	sudo apt install -y ros-humble-desktop ros-dev-tools 

	echo "source /opt/ros/humble/setup.bash" >> ~/.bashrc 
	 
	sleep 2
	gnome-terminal
	echo "Installation Finished! Close this terminal and hop on the new one"
	exit 0
}

virtualbox() {
	echo "Make sure you have your Guest Additions ISO file inserted on your VM!"
	read -rp "Have you inserted your iso? (Y/N): " prompt
	case $prompt in
		[Yy]* ) echo "Starting...";;
		[Nn]* ) "Install the ISO!" && exit 0;;
		* ) echo "Please answer (Y/N)";;
	esac

	sudo apt update && sudo apt -y upgrade
	sudo apt install -y build-essential perl make dbus-x11 curl bzip2

	cd /media/user/VBox* || exit

	sudo bash VBoxLinuxAdditions.run

	echo "make sure to run this script again after reboot in.."
	sleep 3
	echo 3...
	sleep 3
	echo 2...
	sleep 3
	echo 1...
	
	exec reboot

}

physical(){
	sudo apt install -y curl
	post
}


question2 (){
	read -rp $'Are you running this script under a physical machine? (E.g You have Ubuntu Jammy installed on your HDD/SSD?)\nSelect (Y/N): ' yn
	case $yn in
		[Yy]* ) physical;;
		[Nn]* ) "Then you don't need this" && exit 0;;
		* ) echo "Please answer (Y/N)";;
	esac
}

if [[ ${CHECK} -ge 1 ]]; then
	post
fi

read -pr $'Are you running this script under a VirtualBox environment/machine? \nSelect (Y/N): ' yn
	case $yn in
		[Yy]* ) virtualbox;;
		[Nn]* ) question2;;
		* ) echo "Please answer (Y/N)";;
	esac
