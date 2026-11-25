#!/usr/bin/env bash
# Build the signed [star] pacman repository from the latest published release
# of each STAR app. Nothing is compiled here: every package is the one attached
# to the app's GitHub release, checked against that release's SHA256SUMS, then
# signed with the repository key.
#
# Needs: gh (GH_TOKEN), gpg, repo-add, and the armored secret key in
# STAR_SIGNING_KEY. Writes the site to ./public.
set -euo pipefail

apps=(starflux starfold staramp)
arch=x86_64
fingerprint=96D577846B2A55406B6541F88995F50CE7BFC169

root=$(pwd)
out="$root/public/$arch"
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
rm -rf "$root/public"
mkdir -p "$out"

export GNUPGHOME="$work/gnupg"
mkdir -m 700 "$GNUPGHOME"
gpg --batch --quiet --import <<<"$STAR_SIGNING_KEY"
gpg --batch --list-secret-keys --with-colons | grep -q "^fpr:::::::::$fingerprint:" || {
  echo "STAR_SIGNING_KEY is not key $fingerprint" >&2
  exit 1
}

for app in "${apps[@]}"; do
  # Without a tag, gh picks the latest published release: drafts and
  # prereleases are never served.
  if ! tag=$(gh release view -R "bstar/$app" --json tagName --jq .tagName 2>/dev/null); then
    echo "$app: no published release, skipped"
    continue
  fi
  dir="$work/$app"
  mkdir -p "$dir"
  gh release download "$tag" -R "bstar/$app" -D "$dir" \
    -p "$app-*-$arch.pkg.tar.zst" -p SHA256SUMS
  shopt -s nullglob
  pkgs=("$dir"/*.pkg.tar.zst)
  shopt -u nullglob
  if (( ${#pkgs[@]} != 1 )); then
    echo "$app $tag: expected one $arch package, found ${#pkgs[@]}" >&2
    exit 1
  fi
  (cd "$dir" && sha256sum --check --ignore-missing --strict SHA256SUMS)
  name=$(bsdtar -xOf "${pkgs[0]}" .PKGINFO | awk -F' = ' '$1 == "pkgname" {print $2}')
  [[ $name == "$app" ]] || { echo "$app $tag: package is named '$name'" >&2; exit 1; }
  cp "${pkgs[0]}" "$out/"
  gpg --batch --yes --detach-sign --no-armor -u "$fingerprint" "$out/$(basename "${pkgs[0]}")"
  echo "$app $tag: $(basename "${pkgs[0]}")"
done

shopt -s nullglob
served=("$out"/*.pkg.tar.zst)
shopt -u nullglob
(( ${#served[@]} > 0 )) || { echo "no packages to serve" >&2; exit 1; }

repo-add --sign --key "$fingerprint" "$out/star.db.tar.zst" "${served[@]}"
# Pages serves files, not symlinks: replace star.db and star.files with copies.
find "$out" -type l | while read -r link; do
  cp --remove-destination "$(readlink -f "$link")" "$link"
done

cp "$root/site/star.asc" "$root/site/index.html" "$root/setup-star-repo.sh" "$root/public/"
(cd "$out" && ls -1 ./*.pkg.tar.zst | sed 's|^\./||') >"$root/public/packages.txt"
