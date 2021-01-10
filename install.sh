#!/bin/bash

USER=pi

# Changing default password.
sudo passwd ${USER}


# Upgrading system.
echo -e "\e[1;32mSystem upgrade\e[0m"
sleep 5
sudo apt update && sudo apt full-upgrade -y
echo -e "\e[1;32mSystem has been successfully upgraded\e[0m"
sleep 5


# Setting static IP.
echo -e "\e[1;32mSetting static IP\e[0m"
echo -e "\e[1;32mInput Router IP address:\e[0m"
read Router_IP
echo -e "\e[1;32mInput Raspberry Pi static IP address:\e[0m"
read Raspberry_IP
echo "
interface eth0
static ip_address=${Raspberry_IP}
static routers=${Router_IP}
static domain_name_servers=${Router_IP}
" >> /etc/dhcpcd.conf

echo "
interface wlan0
static ip_address=${Raspberry_IP}
static routers=${Router_IP}
static domain_name_servers=${Router_IP}
" >> /etc/dhcpcd.conf

echo "nodhcp" >> /etc/dhcpcd.conf
echo -e "\e[1;32mStatic IP has been set to: ${Raspberry_IP}\e[0m"
sleep 5


# Installing Python 3.8.
version=3.8.5
sudo apt-get install -y build-essential tk-dev libncurses5-dev \
libncursesw5-dev libreadline6-dev libdb5.3-dev libgdbm-dev libsqlite3-dev \
libssl-dev libbz2-dev libexpat1-dev liblzma-dev zlib1g-dev libffi-dev
wget https://www.python.org/ftp/python/${version}/Python-${version}.tgz

tar zxf Python-${version}.tgz
cd Python-${version}
./configure --enable-optimizations
make -j4
sudo make altinstall
echo -e "\e[1;32mChecking Python${version}\e[0m"
python3.8 -V
read -p "\e[1;31m Press ENTER to continue\e[0m" cont
cd
sudo rm -rf Python-${version}.tgz
sudo rm -rf Python-${version}


# Creating a shared folder.
echo -e "\e[1;32mCreating a shared folder\e[0m"
sleep 5
sudo apt install samba -y
sudo cp /etc/samba/smb.conf /etc/samba/initial_smb.conf
chmod -R 0770 /home/${USER}
sudo groupadd smbgrp
sudo usermod -aG smbgrp ${USER}
sudo chgrp smbgrp /home/${USER}
echo -e "\e[1;32mCreating samba ${USER} user password\e[0m"
sudo smbpasswd -a ${USER}

sudo echo "
[pi]
path=/home/${USER}
valid users=${USER}
writable=yes
read only=no
browsable=yes
guest ok=no" >> /etc/samba/smb.conf

sudo /etc/init.d/smbd start
sudo /etc/init.d/smbd restart


# Fan control.
cd /usr/bin
sudo wget https://raw.githubusercontent.com/Notnaim/ras_pi_4/main/fan_control.py
sudo chmod u+x /usr/bin/fan_control.py
# fan autostart
sudo echo "
[Unit]
Description=PWM fan control
After=default.target

[Service]
Type=simple
User=${USER}
ExecStart=/usr/bin/python3 /usr/bin/fan_control.py
Restart=always
RestartSec=5

[Install]
WantedBy=default.target" > /etc/systemd/system/fan_ctrl.service

sudo systemctl --system daemon-reload
sudo systemctl enable fan_ctrl.service
sudo systemctl start fan_ctrl.service
echo -e "\e[1;32m Checking fan service\e[0m"
sudo systemctl status fan_ctrl.service
read -p "\e[1;31m Press ENTER to continue\e[0m" cont




# Overclocking
sudo apt install libgles2-mesa libgles2-mesa-dev xorg-dev -y
sudo cp /boot/config.txt /boot/initial_config.txt
sudo echo "
hdmi_force_hotplug=1
disable_overscan=1
over_voltage=6
arm_freq=2000
h264_freq=700
isp_freq=700
v3d_freq=700
hevc_freq=700
dtparam=audio=on
[pi4]
dtoverlay=vc4-fkms-v3d, cma-128
max_faramebuffers=2
gpu_mem=512
hdmi_enable_4kp60=1
[all]" > /boot/config.txt


# Installing packages
echo -e "\e[1;32m Installing packages \e[0m"
sleep 5
sudo apt install steamlink -y
sudo apt install kodi -y


# connecting bluetooth devices
msg = "Put the bluetooth devices into pairing mode and press ENTER to continue"
echo -e "\e[1;32m${msg}\e[0m"
read cont
REGEXP="([[:xdigit:]]{2}:){5}[[:xdigit:]]{2}"
echo -e "\e[1;32m Search bluetooth devices \e[0m"
timeout 10s bluetoothctl -- scan on > scan.txt
grep -E "20" /home/${USER}/scan.txt > mouse.txt  # 20 is digits in mouse MAC
grep -E "27" /home/${USER}/scan.txt > keyboard.txt  # 27 is digits in kbrd MAC
mouse=$(grep -E -o -m 1 ${REGEXP} mouse.txt)
keyboard=$(grep -E -o -m 1 ${REGEXP} keyboard.txt)
echo -e "\e[1;32m Mouse MAC: ${mouse} \e[0m"
echo -e "\e[1;32m Keyboard MAC: ${keyboard} \e[0m"
bluetoothctl -- pair ${mouse}
bluetoothctl -- connect ${mouse}
bluetoothctl -- trust ${mouse}
bluetoothctl -- pair ${keyboard}
bluetoothctl -- connect ${keyboard}
bluetoothctl -- trust ${keyboard}
rm mouse.txt keyboard.txt scan.txt


# RetroPie installation
git clone --depth=1 https://github.com/RetroPie/RetroPie-Setup.git
cd RetroPie-Setup
chmod +x retropie_setup.sh
sudo ./retropie_setup.sh

# RetroPie desktop shortcut creation
echo "
[Desktop Entry]
Name=RetroPie
Comment=Application for managing and playing retro games
Exec=emulationstation
Icon=/home/${USER}/Pictures/retropie.png
Terminal=true
Path=\$home/bin
Type=Application
Categories=Game;" > home/${USER}/Desktop/RetroPie


# Turn off screen blanking
sudo echo "
[SeatDefaults]
xserver-command=X -s 0 dpms
" >> /etc/lightdm/lightdm.conf

# Installing homeassistant
sudo apt install virtualenv -y
cd /srv
sudo mkdir homeassistant
sudo chown ${USER}:${USER} homeassistant
cd homeassistant
virtualenv --python=/usr/local/bin/python3.8 .
source bin/activate
python3.8 -m pip install wheel
pip3 install homeassistant
# homeassistant autostart
echo "
[Unit]
Description=Home Assistant
After=network-online.target

[Service]
Type=simple
User=${USER}
ExecStart=/srv/homeassistant/bin/hass -c '/home/homeassistant/.homeassistant'
Restart=always

[Install]
WantedBy=multi-user.target" > /etc/systemd/system/homeassistant.service
sudo systemctl --system daemon-reload
sudo systemctl enable homeassistant.service
sudo systemctl start homeassistant.service
echo -e "\e[1;32m Checking fan service \e[0m"
sudo systemctl status homeassistant.service
read -p "\e[1;31m Press ENTER to continue \e[0m" cont

# Manual setting
sudo raspi-config

sudo reboot