#!/usr/bin/env bash
# Build every AUR recipe in aur/ as an unprivileged user, the way an AUR
# helper would, then install the result, run it and remove it again. Run as
# root inside archlinux:latest. Nothing here touches the AUR itself.
set -euo pipefail

pacman -Syu --noconfirm --needed base-devel
id builder >/dev/null 2>&1 || useradd -m builder

work=$(mktemp -d)
chmod 755 "$work"  # mktemp makes it root-only; the builder must enter it
for recipe in aur/*/; do
  name=$(basename "$recipe")
  app=${name%-bin}
  echo "== $name"
  cp -r "$recipe" "$work/$name"
  chown -R builder: "$work/$name"

  # The AUR shows .SRCINFO, so it must describe this exact PKGBUILD.
  runuser -u builder -- bash -c "cd '$work/$name' && makepkg --printsrcinfo" \
    | diff -u "$recipe/.SRCINFO" - \
    || { echo "$name/.SRCINFO is stale; run makepkg --printsrcinfo" >&2; exit 1; }

  # -d: the recipe only repackages, so runtime deps are installed by pacman -U.
  runuser -u builder -- bash -c "cd '$work/$name' && makepkg -d --noconfirm"
  pacman -U --noconfirm "$work/$name"/"$name"-*.pkg.tar.zst

  "$app" --version
  test -f "/usr/share/applications/$app.desktop"
  pacman -Qi "$name" | grep -q "^Provides *: $app="

  pacman -Rns --noconfirm "$name"
  if pacman -Q "$name" >/dev/null 2>&1 || [[ -e /usr/bin/$app ]]; then
    echo "$name is still installed" >&2
    exit 1
  fi
done
