#!/usr/bin/env bash
# Install every served app from the live [star] repository in a fresh Arch
# container, the way a user would, then remove it again. Run as root inside
# archlinux:latest.
set -euo pipefail

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
  if command -v "$app" >/dev/null; then echo "$app still installed" >&2; exit 1; fi
done
