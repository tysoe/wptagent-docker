## Firstly, make sure you have "Known-good kernel 4.14.62" as described in the original installer

# System config
echo '# Limits increased for wptagent' | tee -a /etc/security/limits.conf
echo '* soft nofile 250000' | tee -a /etc/security/limits.conf
echo '* hard nofile 300000' | tee -a /etc/security/limits.conf
echo '# wptagent end' | tee -a /etc/security/limits.conf
echo '# Settings updated for wptagent' | tee -a /etc/sysctl.conf
echo 'net.ipv4.tcp_syn_retries = 4' | tee -a /etc/sysctl.conf

# Boot options
echo 'dtoverlay=pi3-disable-wifi' | tee -a /boot/config.txt
echo 'dtparam=sd_overclock=100' | tee -a /boot/config.txt
echo 'dtparam=watchdog=on' | tee -a /boot/config.txt

# Swap file
echo "CONF_SWAPSIZE=1024" | tee /etc/dphys-swapfile
dphys-swapfile setup
dphys-swapfile swapon
