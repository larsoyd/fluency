setup() {
  # landlock is not allowed in the runner's containers
  grep -q '^DisableSandbox' /etc/pacman.conf || sed -i '/^\[options\]/a DisableSandbox' /etc/pacman.conf
  timeout 1200 pacman -Syu --noconfirm --needed sudo git curl which
}
