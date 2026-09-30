# dots

Arch Linux + Hyprland setup with Rofi.

1. Boot the Arch ISO USB in UEFI mode. In the boot menu, press `e`, append `copytoram=y` to the kernel options, and boot. Lastly, connect to Wi-Fi (replace `wlan0` and `SSID`):

```sh
iwctl device list
iwctl station wlan0 scan
iwctl station wlan0 get-networks
iwctl station wlan0 connect "SSID"
```

2. Clone and bootstrap (erases the selected disk):

```sh
pacman -Sy --needed git
git clone https://github.com/V1K1NGbg/dots.git
cd dots
sudo bash bootstrap.sh
```

3. After reboot, run as your normal user:

```sh
bash ~/dots/install.sh
```