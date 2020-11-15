#!/bin/bash


USER=pi

# changing default password
sudo passwd ${USER}


# Upgrading system
echo -e "\e[1;32mSystem upgrade\e[0m"
sleep 5
sudo apt update && sudo apt full-upgrade -y
echo -e "\e[1;32mSystem has been successfully upgraded\e[0m"
sleep 5


# Setting static IP
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


# Creating a shared folder
echo -e "\e[1;32mCreating a shared folder\e[0m"
sleep 5
sudo apt install samba -y
sudo cp /etc/samba/smb.conf /etc/samba/initial_smb.conf
mkdir RPi4
chmod -R 0770 /home/${USER}/RPi4
sudo groupadd smbgrp
sudo usermod -aG smbgrp ${USER}
sudo chgrp smbgrp /home/${USER}/RPi4
echo -e "\e[1;32mCreating samba ${USER} user password\e[0m"
sudo smbpasswd -a ${USER}

sudo echo "
[RPi4]
path=/home/${USER}/RPi4
valid users=${USER}
writable=yes
read only=no
browsable=yes
guest ok=no" >> /etc/samba/smb.conf

sudo /etc/init.d/smbd start
sudo /etc/init.d/smbd restart


# fan control
sudo mv /home/pi/ras_pi_4/fan_control.py /usr/bin/fan_control.py
sudo chmod u+x /usr/bin/fan_control.py
sudo echo "[Unit]
Description = PWM fan control
After = default.target

[Service]
Type = simple
User = ${USER}
ExecStart = /usr/bin/python3 /usr/bin/fan_control.py
Restart = always
RestartSec = 5

[Install]
WantedBy = default.target" > /etc/systemd/system/fan_ctrl.service

sudo systemctl --system daemon-reload
sudo systemctl enable fan_ctrl.service
sudo systemctl start fan_ctrl.service
echo -e "\e[1;32m Checking fan service \e[0m"
sudo systemctl status fan_ctrl.service
read -p "\e[1;31m Press ENTER to continue \e[0m" cont


# Overclocking
sudo apt install libgles2-mesa libgles2-mesa-dev xorg-dev -y
sudo cp /boot/config.txt /boot/initial_config.txt
sudo echo "disable_overscan=1
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
[all]
" > /boot/config.txt


# Installing packages
echo -e "\e[1;32m Installing packages \e[0m"
sleep 5
sudo apt install steamlink -y
sudo apt install kodi -y


# connecting bluetooth devices
echo -e "\e[1;32mPut the bluetooth devices into pairing mode and press ENTER to continue\e[0m"
read cont
REGEXP="([[:xdigit:]]{2}:){5}[[:xdigit:]]{2}"
echo -e "\e[1;32m Search bluetooth devices \e[0m"
timeout 10s bluetoothctl -- scan on > scan.txt
grep -E "mouse" /home/${USER}/scan.txt > mouse.txt
grep -E "Keyboard" /home/${USER}/scan.txt > keyboard.txt
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


# Manual setting
sudo raspi-config

sudo reboot