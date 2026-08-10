#!/usr/bin/env bash

register_phase system "Hardware & system"

check_autologin() { grep -q -- "--autologin $USER" /etc/systemd/system/getty@tty1.service.d/autologin.conf 2>/dev/null; }
install_autologin() { render_template "$DOTS_ROOT/templates/autologin.conf" /etc/systemd/system/getty@tty1.service.d/autologin.conf; }

check_amd_gpu() { grep -qw amdgpu.dcdebugmask=0x10 /etc/kernel/cmdline 2>/dev/null; }
install_amd_gpu() {
  [[ -f /etc/kernel/cmdline ]] || { warn "/etc/kernel/cmdline not found"; return 1; }
  check_amd_gpu || run sudo sed -i '1s/$/ amdgpu.dcdebugmask=0x10/' /etc/kernel/cmdline
  run sudo dracut --force
}

check_plymouth() {
  grep -qw splash /etc/kernel/cmdline 2>/dev/null &&
    grep -q plymouth /etc/dracut.conf.d/plymouth.conf 2>/dev/null
}
install_plymouth() {
  grep -qw quiet /etc/kernel/cmdline 2>/dev/null || run sudo sed -i '1s/$/ quiet/' /etc/kernel/cmdline
  grep -qw splash /etc/kernel/cmdline 2>/dev/null || run sudo sed -i '1s/$/ splash/' /etc/kernel/cmdline
  render_template "$DOTS_ROOT/templates/plymouth.conf" /etc/dracut.conf.d/plymouth.conf
  run sudo plymouth-set-default-theme hexagon_hud
  run sudo dracut --force
}

check_power_button() { grep -q '^HandlePowerKey=ignore' /etc/systemd/logind.conf.d/10-power-button.conf 2>/dev/null; }
install_power_button() {
  render_template "$DOTS_ROOT/templates/10-power-button.conf" /etc/systemd/logind.conf.d/10-power-button.conf
}

check_bluetooth() { systemctl is-enabled bluetooth.service >/dev/null 2>&1; }
install_bluetooth() { run sudo systemctl enable --now bluetooth.service; }

check_touchpad() { [[ $DESKTOP_PROFILE != awesome ]] || grep -q 'Framework touchpad overrides' /etc/X11/xorg.conf.d/20-touchpad.conf 2>/dev/null; }
install_touchpad() { [[ $DESKTOP_PROFILE != awesome ]] || render_template "$DOTS_ROOT/templates/20-touchpad.conf" /etc/X11/xorg.conf.d/20-touchpad.conf; }

check_keyboard() { [[ $DESKTOP_PROFILE != awesome ]] || grep -q 'us,bg' /etc/X11/xorg.conf.d/00-keyboard.conf 2>/dev/null; }
install_keyboard() { [[ $DESKTOP_PROFILE != awesome ]] || render_template "$DOTS_ROOT/templates/00-keyboard.conf" /etc/X11/xorg.conf.d/00-keyboard.conf; }

check_fusuma_group() { [[ $DESKTOP_PROFILE != awesome ]] || id -nG "$USER" | tr ' ' '\n' | grep -qx input; }
install_fusuma_group() { [[ $DESKTOP_PROFILE != awesome ]] || run sudo usermod -aG input "$USER"; }

check_ctrl_backspace() { grep -qF '"\C-H":"\C-W"' /etc/inputrc 2>/dev/null; }
install_ctrl_backspace() {
  check_ctrl_backspace || run_shell "printf '%s\\n' '\"\\C-H\":\"\\C-W\"' | sudo tee -a /etc/inputrc >/dev/null"
}

check_dns() { grep -q '1.1.1.1,1.0.0.1' /etc/NetworkManager/conf.d/dns-servers.conf 2>/dev/null; }
install_dns() {
  render_template "$DOTS_ROOT/templates/dns-servers.conf" /etc/NetworkManager/conf.d/dns-servers.conf
  run sudo systemctl reload NetworkManager.service
}

check_fingerprint() {
  grep -q '^auth[[:space:]].*pam_fprintd.so' /etc/pam.d/sudo 2>/dev/null &&
    fprintd-list "$USER" 2>/dev/null | grep -q 'finger'
}
install_fingerprint() {
  run fprintd-enroll "$USER"
  if ! grep -q '^auth[[:space:]].*pam_fprintd.so' /etc/pam.d/sudo; then
    run sudo cp -a /etc/pam.d/sudo "/etc/pam.d/sudo.dots-backup-$(date +%s)"
    run sudo sed -i '/#%PAM-1.0/a auth            sufficient      pam_fprintd.so' /etc/pam.d/sudo
  fi
  grep -q '^auth[[:space:]].*pam_fprintd.so' /etc/pam.d/sudo
}

check_docker() { systemctl is-enabled docker.service >/dev/null 2>&1 && id -nG "$USER" | tr ' ' '\n' | grep -qx docker; }
install_docker() {
  run sudo systemctl enable --now docker.service
  run sudo usermod -aG docker "$USER"
}

register_task autologin system "Configure TTY autologin" check_autologin install_autologin "packages" "sudo reboot"
register_task amd-gpu system "Apply Framework AMD fix" check_amd_gpu install_amd_gpu "packages" "sudo reboot"
register_task plymouth system "Configure Plymouth" check_plymouth install_plymouth "packages amd-gpu" "sudo reboot"
register_task power-button system "Ignore physical power key" check_power_button install_power_button "packages" "sudo reboot"
register_task bluetooth system "Enable Bluetooth" check_bluetooth install_bluetooth "packages" "sudo"
register_task touchpad system "Configure touchpad" check_touchpad install_touchpad "packages" "sudo reboot"
register_task keyboard system "Configure Bulgarian layout" check_keyboard install_keyboard "packages" "sudo reboot"
register_task fusuma-group system "Grant input group access" check_fusuma_group install_fusuma_group "packages" "sudo relogin"
register_task ctrl-backspace system "Configure Ctrl+Backspace" check_ctrl_backspace install_ctrl_backspace "packages" "sudo"
register_task dns system "Configure Cloudflare DNS" check_dns install_dns "packages" "sudo"
register_task fingerprint system "Configure fingerprint PAM" check_fingerprint install_fingerprint "packages" "sudo manual"
register_task docker system "Enable Docker" check_docker install_docker "packages" "sudo relogin"
