setup() {
  local obs=https://download.opensuse.org/repositories/home:/AvengeMedia:/danklinux/Debian_Unstable
  export DEBIAN_FRONTEND=noninteractive
  timeout 600 apt-get update && timeout 600 apt-get install -y curl ca-certificates gpg || return
  timeout 60 curl -fsSL "$obs/Release.key" | gpg --dearmor > /usr/share/keyrings/danklinux.gpg || return
  echo "deb [signed-by=/usr/share/keyrings/danklinux.gpg] $obs/ /" > /etc/apt/sources.list.d/danklinux.list
  timeout 600 apt-get update && timeout 1200 apt-get install -y sudo git quickshell
}
