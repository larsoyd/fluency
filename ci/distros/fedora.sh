setup() {
  # the image has a tmpfiles stub where a real system has systemd
  timeout 600 dnf install -y --allowerasing systemd dnf-plugins-core || return
  timeout 300 dnf copr enable -y sdegler/hyprland && timeout 300 dnf copr enable -y errornointernet/quickshell || return
  timeout 1200 dnf install -y sudo git curl quickshell
}
