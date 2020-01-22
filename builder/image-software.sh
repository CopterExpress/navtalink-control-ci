#! /usr/bin/env bash

#
# Script for install software to the image.
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
  TEXT="\e[1m${TEXT}\e[0m" # BOLD

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

# https://gist.github.com/letmaik/caa0f6cc4375cbfcc1ff26bd4530c2a3
# https://github.com/travis-ci/travis-build/blob/master/lib/travis/build/templates/header.sh
my_travis_retry() {
  local result=0
  local count=1
  while [ $count -le 3 ]; do
    [ $result -ne 0 ] && {
      echo -e "\n${ANSI_RED}The command \"$@\" failed. Retrying, $count of 3.${ANSI_RESET}\n" >&2
    }
    # ! { } ignores set -e, see https://stackoverflow.com/a/4073372
    ! { "$@"; result=$?; }
    [ $result -eq 0 ] && break
    count=$(($count + 1))
    sleep 1
  done

  [ $count -gt 3 ] && {
    echo -e "\n${ANSI_RED}The command \"$@\" failed 3 times.${ANSI_RESET}\n" >&2
  }

  return $result
}

echo_stamp "Update apt"
apt-get update
#&& apt upgrade -y

echo_stamp "Remove packages from the base image"
apt-get purge -y \
dhcpcd5 \
openresolv \
&& echo_stamp "Everything was removed!" "SUCCESS" \
|| (echo_stamp "Some packages wasn't removed!" "ERROR"; exit 1)

echo_stamp "Autoremove packages"
apt-get autoremove -y \
&& echo_stamp "Autoremove has been completed!" "SUCCESS" \
|| (echo_stamp "Failed to complete autoremove!" "ERROR"; exit 1)

echo_stamp "Software installing"
apt-get install --no-install-recommends -y \
openbox \
libqt5concurrent5 \
qtvirtualkeyboard-plugin \
lightdm \
libsdl2-dev \
gstreamer1.0-libav \
xinit \
xserver-xorg \
network-manager \
network-manager-openvpn \
network-manager-gnome \
xfce4-panel \
onboard \
qterminal \
crudini \
plymouth \
plymouth-themes \
nitrogen \
&& echo_stamp "Everything was installed!" "SUCCESS" \
|| (echo_stamp "Some packages wasn't installed!" "ERROR"; exit 1)

echo_stamp "Unpack QGroundControl"
tar xf "/home/pi/${QGC_ASSET}" -C /home/pi \
&& rm "/home/pi/${QGC_ASSET}" \
|| (echo_stamp "Failed to unpack QGroundControl!" "ERROR"; exit 1)

echo_stamp "Configure services"
systemctl enable qgc \
|| (echo_stamp "Failed to configure services!" "ERROR"; exit 1)

echo_stamp "Set GS role"
cp -f /home/pi/navtalink/wifibroadcast.cfg.gs /boot/wifibroadcast.txt \
&& systemctl enable wifibroadcast@gs \
|| (echo_stamp "Failed to set role!" "ERROR"; exit 1)

echo_stamp "Add xfce4-panel to autostart"
echo 'xfce4-panel &' >> /home/pi/.config/openbox/autostart

echo_stamp "Add onboard to autostart"
echo 'onboard &' >> /home/pi/.config/openbox/autostart

echo_stamp "Add nitrogen to autostart"
echo 'nitrogen --restore &' >> /home/pi/.config/openbox/autostart

echo_stamp "Add nm-applet to autostart"
echo 'nm-applet &' >> /home/pi/.config/openbox/autostart

echo_stamp "Edit cmdline.txt"
sed -i '1 s_$_ splash logo.nologo_' /boot/cmdline.txt \
|| (echo_stamp "Failed to edit cmdline.txt!" "ERROR"; exit 1)

echo_stamp "Edit plymouthd.conf"
crudini --set /etc/plymouth/plymouthd.conf 'Daemon' 'Theme' 'spinfinity' \
|| (echo_stamp "Failed to edit plymouthd.conf!" "ERROR"; exit 1)

echo_stamp "Change files owner"
chown -R pi:pi /home/pi/.config \
&& chown -R pi:pi /home/pi/Documents \
|| (echo_stamp "Failed to change files owner!" "ERROR"; exit 1)

echo_stamp "End of software installation"
