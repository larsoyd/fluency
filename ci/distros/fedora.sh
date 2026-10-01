setup() {
  # the openh264 repo is a third party host that timed out, fedora's own noopenh264 stands in
  [ ! -f /etc/yum.repos.d/fedora-cisco-openh264.repo ] || sed -i 's/^enabled=1/enabled=0/' /etc/yum.repos.d/fedora-cisco-openh264.repo || return
  # the image has a tmpfiles stub where a real system has systemd
  timeout 600 dnf install -y --allowerasing systemd dnf-plugins-core || return
  timeout 300 dnf copr enable -y sdegler/hyprland && timeout 300 dnf copr enable -y errornointernet/quickshell || return
  timeout 1200 dnf install -y sudo git curl quickshell
}
