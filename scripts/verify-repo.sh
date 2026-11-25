#!/usr/bin/env bash
# Install every served app from the live [star] repository in a fresh Arch
# container, the way a user would, then remove it again. Run as root inside
# archlinux:latest.
set -euo pipefail

# The archlinux image ships without a local master key, which every installed
# system has and pacman-key --lsign-key needs.
pacman-key --init
STAR_SETUP_YES=1 bash ./setup-star-repo.sh
pacman -Syu --noconfirm

mapfile -t apps < <(pacman -Slq star)
(( ${#apps[@]} > 0 )) || { echo "[star] lists no packages" >&2; exit 1; }
echo "[star] serves: ${apps[*]}"

for app in "${apps[@]}"; do
  pacman -S --noconfirm "$app"
  "$app" --version
  test -f "/usr/share/applications/$app.desktop"
  pacman -Rns --noconfirm "$app"
  if pacman -Q "$app" >/dev/null 2>&1 || [[ -e /usr/bin/$app ]]; then
    echo "$app is still installed" >&2
    exit 1
  fi
done
