#!/bin/bash

# Prompt for the configuration options
echo "Automatic agent install and configuration."
echo

AGENT_MODE=$ARG_AGENT_MODE

DISABLE_IPV6=$ARG_DISABLE_IPV6
WPT_SERVER=$ARG_WPT_SERVER
WPT_LOCATION=$ARG_WPT_LOCATION
WPT_KEY=$ARG_WPT_KEY
WPT_DEVICE_NAME=$ARG_WPT_DEVICE_NAME

echo "Trimming filesystem..."
fstrim -v /

cd ~
until apt -y update
do
    sleep 1
done

# Install OS packages
until DEBIAN_FRONTEND=noninteractive apt -yq -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" dist-upgrade
do
    sleep 1
done
curl -sL https://deb.nodesource.com/setup_12.x | bash -
echo ttf-mscorefonts-installer msttcorefonts/accepted-mscorefonts-eula select true | debconf-set-selections
until DEBIAN_FRONTEND=noninteractive apt install -yq git screen watchdog \
libtiff5-dev libjpeg-dev zlib1g-dev libfreetype6-dev liblcms2-dev libwebp-dev tcl8.6-dev tk8.6-dev python-tk python2.7 python-pip \
python-dev libavutil-dev libmp3lame-dev libx264-dev yasm autoconf automake build-essential libass-dev libfreetype6-dev libtheora-dev \
libtool libvorbis-dev pkg-config texi2html libtext-unidecode-perl python-numpy python-scipy \
imagemagick ffmpeg adb traceroute software-properties-common psmisc libnss3-tools iproute2 net-tools ethtool nodejs \
cmake git-core libsdl2-dev libva-dev libvdpau-dev libxcb1-dev libxcb-shm0-dev libxcb-xfixes0-dev texinfo wget
do
    sleep 1
done
if [ "${AGENT_MODE,,}" == 'desktop' ]; then
  until DEBIAN_FRONTEND=noninteractive apt install -yq xvfb dbus-x11 \
  cgroup-tools chromium-browser firefox-esr ttf-mscorefonts-installer fonts-noto*
  do
      sleep 1
  done
fi
apt install -y software-properties-common
until npm install -g lighthouse
do
    sleep 1
done
npm update -g
if [ "${AGENT_MODE,,}" == 'desktop' ]; then
  dbus-uuidgen --ensure
  fc-cache -f -v
fi

# Set up python
until pip install dnspython monotonic pillow psutil pyssim requests git+git://github.com/marshallpierce/ultrajson.git@v1.35-gentoo-fixes tornado wsaccel xvfbwrapper brotli 'fonttools>=3.44.0,<4.0.0' marionette_driver
do
    sleep 1
done
until git clone https://github.com/WPO-Foundation/wptagent.git
do
    sleep 1
done
cd ~/wptagent
git checkout origin/release
cd ~

# ffmpeg
cd ~
git clone --depth 1 https://github.com/FFmpeg/FFmpeg.git ffmpeg
cd ffmpeg
./configure --arch=$ARG_MAKE_ARCH --target-os=linux --enable-gpl --enable-libx264 --enable-nonfree
make -j4
make install
cd ~
rm -rf ffmpeg

# iOS support
if [ "${AGENT_MODE,,}" == 'ios' ]; then
  until DEBIAN_FRONTEND=noninteractive apt -yq install build-essential \
  cmake python-dev cython swig automake autoconf libtool libusb-1.0-0 libusb-1.0-0-dev \
  libreadline-dev openssl libssl1.0.2 libssl1.1 libssl-dev
  do
      sleep 1
  done
  cd ~

  git clone --depth 1 https://github.com/libimobiledevice/libplist.git libplist
  cd libplist
  ./autogen.sh
  make
  make install
  cd ~
  rm -rf libplist

  git clone --depth 1 https://github.com/libimobiledevice/libusbmuxd.git libusbmuxd
  cd libusbmuxd
  ./autogen.sh
  make
  make install
  cd ~
  rm -rf libusbmuxd

  git clone --depth 1 https://github.com/libimobiledevice/libimobiledevice.git libimobiledevice
  cd libimobiledevice
  ./autogen.sh
  make
  make install
  cd ~
  rm -rf libimobiledevice

  git clone --depth 1 https://github.com/libimobiledevice/usbmuxd.git usbmuxd
  cd usbmuxd
  ./autogen.sh
  make
  make install
  cd ~
  rm -rf usbmuxd

  git clone --depth 1 https://github.com/google/ios-webkit-debug-proxy.git ios-webkit-debug-proxy
  cd ios-webkit-debug-proxy
  ./autogen.sh
  make
  make install
  cd ~
  rm -rf ios-webkit-debug-proxy

  sh -c 'echo /usr/local/lib > /etc/ld.so.conf.d/libimobiledevice-libs.conf'
  ldconfig
fi

# disable IPv6 if requested
if [ "${DISABLE_IPV6,,}" == 'y' ]; then
  echo "net.ipv6.conf.all.disable_ipv6 = 1" | tee -a /etc/sysctl.conf
  echo "net.ipv6.conf.default.disable_ipv6 = 1" | tee -a /etc/sysctl.conf
  echo "net.ipv6.conf.lo.disable_ipv6 = 1" | tee -a /etc/sysctl.conf
fi

# Reboot when out of memory
echo "vm.panic_on_oom=1" | tee -a /etc/sysctl.conf
echo "kernel.panic=10" | tee -a /etc/sysctl.conf

# disable IPv6 if requested
if [ "${DISABLE_IPV6,,}" == 'y' ]; then
  echo "net.ipv6.conf.all.disable_ipv6 = 1" | tee -a /etc/sysctl.conf
  echo "net.ipv6.conf.default.disable_ipv6 = 1" | tee -a /etc/sysctl.conf
  echo "net.ipv6.conf.lo.disable_ipv6 = 1" | tee -a /etc/sysctl.conf
fi

echo '# wptagent end' | tee -a /etc/sysctl.conf
sysctl -p

# disable hardware checksum offload
sed -i 's/exit 0/ethtool --offload eth0 rx off tx off\nexit 0/g' /etc/network/interfaces

# configure adb
gpasswd -a $USER plugdev
mkdir -p /etc/udev/rules.d/
if [ "${AGENT_MODE,,}" == 'android' ]; then
  echo "SUBSYSTEM==\"usb\", ATTR{idVendor}==\"0502\", MODE=\"0666\", GROUP=\"plugdev\", OWNER=\"$USER\"" | tee /etc/udev/rules.d/51-android.rules
  echo "SUBSYSTEM==\"usb\", ATTR{idVendor}==\"0b05\", MODE=\"0666\", GROUP=\"plugdev\", OWNER=\"$USER\"" | tee -a /etc/udev/rules.d/51-android.rules
  echo "SUBSYSTEM==\"usb\", ATTR{idVendor}==\"413c\", MODE=\"0666\", GROUP=\"plugdev\", OWNER=\"$USER\"" | tee -a /etc/udev/rules.d/51-android.rules
  echo "SUBSYSTEM==\"usb\", ATTR{idVendor}==\"0489\", MODE=\"0666\", GROUP=\"plugdev\", OWNER=\"$USER\"" | tee -a /etc/udev/rules.d/51-android.rules
  echo "SUBSYSTEM==\"usb\", ATTR{idVendor}==\"04c5\", MODE=\"0666\", GROUP=\"plugdev\", OWNER=\"$USER\"" | tee -a /etc/udev/rules.d/51-android.rules
  echo "SUBSYSTEM==\"usb\", ATTR{idVendor}==\"091e\", MODE=\"0666\", GROUP=\"plugdev\", OWNER=\"$USER\"" | tee -a /etc/udev/rules.d/51-android.rules
  echo "SUBSYSTEM==\"usb\", ATTR{idVendor}==\"18d1\", MODE=\"0666\", GROUP=\"plugdev\", OWNER=\"$USER\"" | tee -a /etc/udev/rules.d/51-android.rules
  echo "SUBSYSTEM==\"usb\", ATTR{idVendor}==\"201e\", MODE=\"0666\", GROUP=\"plugdev\", OWNER=\"$USER\"" | tee -a /etc/udev/rules.d/51-android.rules
  echo "SUBSYSTEM==\"usb\", ATTR{idVendor}==\"109b\", MODE=\"0666\", GROUP=\"plugdev\", OWNER=\"$USER\"" | tee -a /etc/udev/rules.d/51-android.rules
  echo "SUBSYSTEM==\"usb\", ATTR{idVendor}==\"12d1\", MODE=\"0666\", GROUP=\"plugdev\", OWNER=\"$USER\"" | tee -a /etc/udev/rules.d/51-android.rules
  echo "SUBSYSTEM==\"usb\", ATTR{idVendor}==\"8087\", MODE=\"0666\", GROUP=\"plugdev\", OWNER=\"$USER\"" | tee -a /etc/udev/rules.d/51-android.rules
  echo "SUBSYSTEM==\"usb\", ATTR{idVendor}==\"24e3\", MODE=\"0666\", GROUP=\"plugdev\", OWNER=\"$USER\"" | tee -a /etc/udev/rules.d/51-android.rules
  echo "SUBSYSTEM==\"usb\", ATTR{idVendor}==\"2116\", MODE=\"0666\", GROUP=\"plugdev\", OWNER=\"$USER\"" | tee -a /etc/udev/rules.d/51-android.rules
  echo "SUBSYSTEM==\"usb\", ATTR{idVendor}==\"17ef\", MODE=\"0666\", GROUP=\"plugdev\", OWNER=\"$USER\"" | tee -a /etc/udev/rules.d/51-android.rules
  echo "SUBSYSTEM==\"usb\", ATTR{idVendor}==\"1004\", MODE=\"0666\", GROUP=\"plugdev\", OWNER=\"$USER\"" | tee -a /etc/udev/rules.d/51-android.rules
  echo "SUBSYSTEM==\"usb\", ATTR{idVendor}==\"22b8\", MODE=\"0666\", GROUP=\"plugdev\", OWNER=\"$USER\"" | tee -a /etc/udev/rules.d/51-android.rules
  echo "SUBSYSTEM==\"usb\", ATTR{idVendor}==\"0e8d\", MODE=\"0666\", GROUP=\"plugdev\", OWNER=\"$USER\"" | tee -a /etc/udev/rules.d/51-android.rules
  echo "SUBSYSTEM==\"usb\", ATTR{idVendor}==\"0409\", MODE=\"0666\", GROUP=\"plugdev\", OWNER=\"$USER\"" | tee -a /etc/udev/rules.d/51-android.rules
  echo "SUBSYSTEM==\"usb\", ATTR{idVendor}==\"2080\", MODE=\"0666\", GROUP=\"plugdev\", OWNER=\"$USER\"" | tee -a /etc/udev/rules.d/51-android.rules
  echo "SUBSYSTEM==\"usb\", ATTR{idVendor}==\"0955\", MODE=\"0666\", GROUP=\"plugdev\", OWNER=\"$USER\"" | tee -a /etc/udev/rules.d/51-android.rules
  echo "SUBSYSTEM==\"usb\", ATTR{idVendor}==\"2257\", MODE=\"0666\", GROUP=\"plugdev\", OWNER=\"$USER\"" | tee -a /etc/udev/rules.d/51-android.rules
  echo "SUBSYSTEM==\"usb\", ATTR{idVendor}==\"10a9\", MODE=\"0666\", GROUP=\"plugdev\", OWNER=\"$USER\"" | tee -a /etc/udev/rules.d/51-android.rules
  echo "SUBSYSTEM==\"usb\", ATTR{idVendor}==\"1d4d\", MODE=\"0666\", GROUP=\"plugdev\", OWNER=\"$USER\"" | tee -a /etc/udev/rules.d/51-android.rules
  echo "SUBSYSTEM==\"usb\", ATTR{idVendor}==\"0471\", MODE=\"0666\", GROUP=\"plugdev\", OWNER=\"$USER\"" | tee -a /etc/udev/rules.d/51-android.rules
  echo "SUBSYSTEM==\"usb\", ATTR{idVendor}==\"04da\", MODE=\"0666\", GROUP=\"plugdev\", OWNER=\"$USER\"" | tee -a /etc/udev/rules.d/51-android.rules
  echo "SUBSYSTEM==\"usb\", ATTR{idVendor}==\"05c6\", MODE=\"0666\", GROUP=\"plugdev\", OWNER=\"$USER\"" | tee -a /etc/udev/rules.d/51-android.rules
  echo "SUBSYSTEM==\"usb\", ATTR{idVendor}==\"1f53\", MODE=\"0666\", GROUP=\"plugdev\", OWNER=\"$USER\"" | tee -a /etc/udev/rules.d/51-android.rules
  echo "SUBSYSTEM==\"usb\", ATTR{idVendor}==\"04e8\", MODE=\"0666\", GROUP=\"plugdev\", OWNER=\"$USER\"" | tee -a /etc/udev/rules.d/51-android.rules
  echo "SUBSYSTEM==\"usb\", ATTR{idVendor}==\"04dd\", MODE=\"0666\", GROUP=\"plugdev\", OWNER=\"$USER\"" | tee -a /etc/udev/rules.d/51-android.rules
  echo "SUBSYSTEM==\"usb\", ATTR{idVendor}==\"054c\", MODE=\"0666\", GROUP=\"plugdev\", OWNER=\"$USER\"" | tee -a /etc/udev/rules.d/51-android.rules
  echo "SUBSYSTEM==\"usb\", ATTR{idVendor}==\"0fce\", MODE=\"0666\", GROUP=\"plugdev\", OWNER=\"$USER\"" | tee -a /etc/udev/rules.d/51-android.rules
  echo "SUBSYSTEM==\"usb\", ATTR{idVendor}==\"2340\", MODE=\"0666\", GROUP=\"plugdev\", OWNER=\"$USER\"" | tee -a /etc/udev/rules.d/51-android.rules
  echo "SUBSYSTEM==\"usb\", ATTR{idVendor}==\"0930\", MODE=\"0666\", GROUP=\"plugdev\", OWNER=\"$USER\"" | tee -a /etc/udev/rules.d/51-android.rules
  echo "SUBSYSTEM==\"usb\", ATTR{idVendor}==\"2970\", MODE=\"0666\", GROUP=\"plugdev\", OWNER=\"$USER\"" | tee -a /etc/udev/rules.d/51-android.rules
  echo "SUBSYSTEM==\"usb\", ATTR{idVendor}==\"1ebf\", MODE=\"0666\", GROUP=\"plugdev\", OWNER=\"$USER\"" | tee -a /etc/udev/rules.d/51-android.rules
  echo "SUBSYSTEM==\"usb\", ATTR{idVendor}==\"19d2\", MODE=\"0666\", GROUP=\"plugdev\", OWNER=\"$USER\"" | tee -a /etc/udev/rules.d/51-android.rules
  echo "SUBSYSTEM==\"usb\", ATTR{idVendor}==\"2b4c\", MODE=\"0666\", GROUP=\"plugdev\", OWNER=\"$USER\"" | tee -a /etc/udev/rules.d/51-android.rules
  echo "SUBSYSTEM==\"usb\", ATTR{idVendor}==\"0bb4\", MODE=\"0666\", GROUP=\"plugdev\", OWNER=\"$USER\"" | tee -a /etc/udev/rules.d/51-android.rules
  echo "SUBSYSTEM==\"usb\", ATTR{idVendor}==\"1bbb\", MODE=\"0666\", GROUP=\"plugdev\", OWNER=\"$USER\"" | tee -a /etc/udev/rules.d/51-android.rules
  echo "SUBSYSTEM==\"usb\", ATTR{idVendor}==\"2a70\", MODE=\"0666\", GROUP=\"plugdev\", OWNER=\"$USER\"" | tee -a /etc/udev/rules.d/51-android.rules
  #cp ~/wptagent/misc/adb/arm/adb /usr/bin/adb
  udevadm control --reload-rules
  service udev restart
fi

# build the startup script
echo '#!/bin/sh' > ~/startup.sh
echo "PATH=$PWD/bin:$PWD/.local/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/games:/usr/local/games:/snap/bin" >> ~/startup.sh
echo 'screen -dmS agent ~/agent.sh' >> ~/startup.sh
echo 'service watchdog restart' >> ~/startup.sh
chmod +x ~/startup.sh

# build the agent script
KEY_OPTION=''
if [ $WPT_KEY != '' ]; then
  KEY_OPTION="--key $WPT_KEY"
fi
NAME_OPTION=''
if [ $WPT_DEVICE_NAME != '' ]; then
  NAME_OPTION="--name \"$WPT_DEVICE_NAME\""
fi
echo '#!/bin/sh' > ~/agent.sh
echo 'export DEBIAN_FRONTEND=noninteractive' >> ~/agent.sh
echo 'cd ~/wptagent' >> ~/agent.sh
echo 'echo "Waiting for 30 second startup delay"' >> ~/agent.sh
echo 'sleep 30' >> ~/agent.sh
echo 'echo "Updating OS"' >> ~/agent.sh
echo 'until apt -y update' >> ~/agent.sh
echo 'do' >> ~/agent.sh
echo '    sleep 1' >> ~/agent.sh
echo 'done' >> ~/agent.sh
echo 'until DEBIAN_FRONTEND=noninteractive apt -yq -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" dist-upgrade' >> ~/agent.sh
echo 'do' >> ~/agent.sh
echo '    apt -f install' >> ~/agent.sh
echo '    sleep 1' >> ~/agent.sh
echo 'done' >> ~/agent.sh
echo 'npm i -g lighthouse' >> ~/agent.sh
echo 'fstrim -v /' >> ~/agent.sh
if [ "${AGENT_MODE,,}" == 'ios' ]; then
  echo 'usbmuxd' >> ~/agent.sh
fi
echo 'for i in `seq 1 24`' >> ~/agent.sh
echo 'do' >> ~/agent.sh
echo '    git pull origin release' >> ~/agent.sh
if [ "${AGENT_MODE,,}" == 'android' ]; then
  echo "    python wptagent.py -vvvv $NAME_OPTION --location $WPT_LOCATION $KEY_OPTION --server \"http://$WPT_SERVER/work/\" --android --exit 60 --alive /tmp/wptagent" >> ~/agent.sh
  echo "#    python wptagent.py -vvvv $NAME_OPTION --location $WPT_LOCATION $KEY_OPTION --server \"http://$WPT_SERVER/work/\" --android --vpntether eth0,192.168.0.1 --shaper netem,eth0 --exit 60 --alive /tmp/wptagent" >> ~/agent.sh
fi
if [ "${AGENT_MODE,,}" == 'ios' ]; then
  echo "    python wptagent.py -vvvv $NAME_OPTION --location $WPT_LOCATION $KEY_OPTION --server \"http://$WPT_SERVER/work/\" --iOS --exit 60 --alive /tmp/wptagent" >> ~/agent.sh
fi
if [ "${AGENT_MODE,,}" == 'desktop' ]; then
  echo "    python wptagent.py -vvvv $NAME_OPTION --location $WPT_LOCATION $KEY_OPTION --server \"http://$WPT_SERVER/work/\" --xvfb --exit 60 --alive /tmp/wptagent" >> ~/agent.sh
fi
echo '    echo "Exited, restarting"' >> ~/agent.sh
echo '    sleep 1' >> ~/agent.sh
echo 'done' >> ~/agent.sh
echo 'apt -y autoremove' >> ~/agent.sh
echo 'apt clean' >> ~/agent.sh
if [ "${AGENT_MODE,,}" == 'android' ]; then
  echo 'adb reboot' >> ~/agent.sh
fi
if [ "${AGENT_MODE,,}" == 'ios' ]; then
  echo 'idevicediagnostics restart' >> ~/agent.sh
fi
echo 'reboot' >> ~/agent.sh
chmod +x ~/agent.sh

# add it to the crontab
CRON_ENTRY="@reboot $PWD/startup.sh"
( crontab -l | grep -v -F "$CRON_ENTRY" ; echo "$CRON_ENTRY" ) | crontab -

apt -y autoremove
apt clean

# configure watchdog
touch /tmp/wptagent
echo "bcm2835_wdt" | tee -a /etc/modules
update-rc.d watchdog defaults
echo "watchdog-device = /dev/watchdog" | tee -a /etc/watchdog.conf
echo "watchdog-timeout = 15" | tee -a /etc/watchdog.conf
echo "test-binary = $PWD/wptagent/alive.sh" | tee -a /etc/watchdog.conf
modprobe bcm2835_wdt
echo "RuntimeWatchdogSec=10s" | tee -a /etc/systemd/system.conf
echo "ShutdownWatchdogSec=10min" | tee -a /etc/systemd/system.conf
echo "WantedBy=multi-user.target" | tee -a /lib/systemd/system/watchdog.service
systemctl start watchdog
systemctl status watchdog
systemctl enable watchdog

# Handle device prompts
if [ "${AGENT_MODE,,}" == 'android' ]; then
  adb devices -l
fi
if [ "${AGENT_MODE,,}" == 'ios' ]; then
  usbmuxd
  sleep 20
  ideviceinfo
fi

cd ~
echo
echo "Install is complete.  Please reboot the system to start testing (reboot)"