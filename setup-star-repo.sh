#!/usr/bin/env bash
# Add the signed [star] package repository to pacman.
#
# Read this script before running it. It prints every step and asks once
# before it changes anything. It trusts one key, the fingerprint below, and
# only for packages from this repository; it never installs a package.
set -euo pipefail

url=https://bstar.github.io/star-packages
fingerprint=96D577846B2A55406B6541F88995F50CE7BFC169

sudo=sudo
(( EUID == 0 )) && sudo=

key=$(mktemp)
trap 'rm -f "$key"' EXIT
curl -fsSL "$url/star.asc" -o "$key"
got=$(gpg --show-keys --with-colons "$key" 2>/dev/null | awk -F: '/^fpr/ {print $10; exit}')
if [[ $got != "$fingerprint" ]]; then
  echo "The downloaded key is $got, expected $fingerprint. Stopping." >&2
  exit 1
fi

cat <<EOF
This will:
  1. add the STAR package key $fingerprint to pacman's keyring
     (pacman-key --add, then --lsign-key);
  2. add this to /etc/pacman.conf, unless a [star] section is already there:

     [star]
     SigLevel = Required DatabaseRequired
     Server = $url/\$arch

Nothing is installed. Afterwards, install an app with:
  sudo pacman -Syu starflux     (or starfold, staramp)

To undo: delete the [star] section from /etc/pacman.conf and run
  sudo pacman-key --delete $fingerprint
EOF

if [[ ${STAR_SETUP_YES:-} != 1 ]]; then
  read -r -p "Continue? [y/N] " answer
  [[ $answer == [yY]* ]] || { echo "Nothing changed."; exit 0; }
fi

$sudo pacman-key --add "$key"
$sudo pacman-key --lsign-key "$fingerprint"
if grep -q '^\[star\]' /etc/pacman.conf; then
  echo "/etc/pacman.conf already has a [star] section; left it as it is."
else
  printf '\n[star]\nSigLevel = Required DatabaseRequired\nServer = %s/$arch\n' "$url" |
    $sudo tee -a /etc/pacman.conf >/dev/null
  echo "Added [star] to /etc/pacman.conf."
fi
echo "Done. Install with: sudo pacman -Syu starflux"
