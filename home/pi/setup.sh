#!/bin/bash

# Copyright 2018 Mycroft AI Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

##########################################################################
# setup.sh
##########################################################################
# This script sets up a Mark 2 Pi based off of a Mark 1 image

REPO_PATH="https://raw.githubusercontent.com/MycroftAI/enclosure-mark2/master"

# Remove Debian package versions of Core and Mark 1 and Arduino bits
sudo kill -9 $(pgrep mycroft)
sudo rm /etc/cron.hourly/mycroft-core
sudo apt-get purge -y mycroft-core

# Update mycroft-wifi-setup so update does not reinstall mycroft-core package
sudo apt-get update -y
sudo apt-get install -y mycroft-wifi-setup

# Correct permissions from Mark 1 (which used the 'mycroft' user to run)
sudo chown -R pi:pi /var/log/mycroft
rm /var/log/mycroft/*
sudo chown -R pi:pi /opt/mycroft
rm -rf /tmp/*

# Locale fix
sudo sed -i.bak 's|AcceptEnv LANG LC_\*||' /etc/ssh/sshd_config

# Display Setup
sudo echo "# Mark 2 Pi Display Settings" | sudo tee -a /boot/config.txt    
sudo echo "hdmi_force_hotplug=1" | sudo tee -a /boot/config.txt
sudo echo "hdmi_drive=2" | sudo tee -a /boot/config.txt
sudo echo "hdmi_group=2" | sudo tee -a /boot/config.txt
sudo echo "hdmi_mode=87" | sudo tee -a /boot/config.txt
sudo echo "display_rotate=1" | sudo tee -a /boot/config.txt
sudo echo "hdmi_cvt 800 400 60 6 0 0 0" | sudo tee -a /boot/config.txt

# Removing boot up text printed to tty1 console
sudo echo "dwc_otg.lpm_enable=0 console=tty2 logo.nologo root=/dev/mmcblk0p2 rootfstype=ext4 elevator=deadline fsck.repair=yes rootwait consoleblank=0 quiet splash plymouth.ignore-serial-consoles vt.global_cursor_default=0" | sudo tee /boot/cmdline
sudo sed -i.bak -e 's|ExecStart.*|ExecStart=-/sbin/agetty --skip-login --noclear --noissue --login-options "-f pi" %I $TERM|' /etc/systemd/system/autologin@.service
sudo sed -i.bak -e 's| /bin/uname -snrvm||' /etc/pam.d/login
touch ~/.hushlogin

# GUI: Install plymouth
git clone https://github.com/forslund/mycroft-plymouth-theme
cd mycroft-plymouth-theme
echo -n "Press any key? Okay!" | ./install.sh
cd ~
sudo plymouth-set-default-theme mycroft-plymouth-theme

# Volume: Install I2C support (might require raspi-config changes first)
sudo apt-get install -y i2c-tools
sudo raspi-config nonint do_i2c 0

# Get the Picroft conf file
cd /etc/mycroft
sudo wget $REPO_PATH/etc/mycroft/mycroft.conf
cd ~

wget $REPO_PATH/home/pi/.bashrc
wget $REPO_PATH/home/pi/auto_run.sh
wget $REPO_PATH/home/pi/mycroft.fb

mkdir -p ~/bin
cd ~/bin
wget $REPO_PATH/home/pi/bin/mycroft-wipe
chmod +x mycroft-wipe
cd ~

# mycroft-core
git clone https://github.com/MycroftAI/mycroft-core.git
cd mycroft-core
IS_TRAVIS=true bash dev_setup.sh 2>&1 | tee ../build.log
# Keep for now.
#rm ../build.log
cd ~

# Streaming STT
pip install google-cloud-speech
# Insert stt key, remove placeholder comment, format and write to file.
sed '/# Google Service Key/r /boot/stt.json' /etc/mycroft/mycroft.conf \
    | sed 's|# Google Service.*||' \
    | python -m json.tool \
    | sudo tee /etc/mycroft/mycroft.conf

# skills
~/mycroft-core/bin/mycroft-msm default
~/mycroft-core/bin/mycroft-msm install skill-mark-2
cd /opt/mycroft/skills/mycroft-spotify.forslund/ && git pull && cd ~

# Development
sudo raspi-config nonint do_ssh 0
sudo apt-get install -y tmux
sudo apt-get autoremove -y
sudo rm -rf /var/lib/apt/lists/*
rm -rf ~/.cache/*