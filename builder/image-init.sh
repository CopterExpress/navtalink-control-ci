#! /usr/bin/env bash

#
# Script for initialisation image
#
# Copyright (C) 2019 Copter Express Technologies
#
# Author: Artem Smirnov <urpylka@gmail.com>
# Author: Andrey Dvornikov <dvornikov-aa@yandex.ru>
#

set -e # Exit immidiately on non-zero result

echo_stamp() {
  # TEMPLATE: echo_stamp <TEXT> <TYPE>
  # TYPE: SUCCESS, ERROR, INFO

  # More info there https://www.shellhacks.com/ru/bash-colors/

  TEXT="$(date '+[%Y-%m-%d %H:%M:%S]') $1"
  TEXT="\e[1m$TEXT\e[0m" # BOLD

  case "$2" in
    SUCCESS)
    TEXT="\e[32m${TEXT}\e[0m";; # GREEN
    ERROR)
    TEXT="\e[31m${TEXT}\e[0m";; # RED
    *)
    TEXT="\e[34m${TEXT}\e[0m";; # BLUE
  esac
  echo -e ${TEXT}
}

echo_stamp "Write NavTALink control information"

# NavTALink Control image version
echo "$1" >> /etc/navtalink_control
# Origin image file name
echo "${2%.*}" >> /etc/navtalink_control_origin

cat <<EOT >> /root/hardware_setup.sh

# 1. Change boot behaviour to desktop GUI with autologin
echo_stamp "#1 Change boot behaviour to desktop GUI with autologin"
SUDO_USER=pi /usr/bin/raspi-config nonint do_boot_behaviour B4

# 2. Increase GPU memory
echo_stamp "#2 Increase GPU memory"
/usr/bin/raspi-config nonint do_memory_split 256

# 4. Set OpenGL driver
echo_stamp "#3 Set OpenGL driver"
# /usr/bin/raspi-config nonint do_gldriver G2
echo "dtoverlay=vc4-fkms-v3d" >> /boot/config.txt

# 3. Disable waiting for network
echo_stamp "#4 Disable waiting for network"
/usr/bin/raspi-config nonint do_boot_wait 1

echo_stamp "#5 End of configure hardware interfaces"
EOT

echo_stamp "End of init image"
