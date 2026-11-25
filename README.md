# [star] pacman repository

A signed Arch Linux package repository for the STAR apps:
[STAR/FLUX](https://github.com/bstar/starflux),
[STAR/FOLD](https://github.com/bstar/starfold) and
[STAR/AMP](https://github.com/bstar/staramp). Once it's set up, the apps update
with the rest of the system on `pacman -Syu`, which is also what `omarchy update`
runs.

## Set it up

Download the setup script, read it, then run it. It adds the signing key and
the `[star]` section to `/etc/pacman.conf`, asks once before changing anything,
and installs nothing.

```sh
curl -fsSLO https://bstar.github.io/star-packages/setup-star-repo.sh
less setup-star-repo.sh
bash setup-star-repo.sh
sudo pacman -Syu starflux     # or starfold, staramp
```

On Omarchy, `omarchy pkg add starflux` works too, after the first
`sudo pacman -Syu` has fetched the `[star]` database.

To do it by hand instead:

```sh
curl -fsSL https://bstar.github.io/star-packages/star.asc -o star.asc
sudo pacman-key --add star.asc
sudo pacman-key --lsign-key 96D577846B2A55406B6541F88995F50CE7BFC169
```

Then add this to `/etc/pacman.conf`:

```ini
[star]
SigLevel = Required DatabaseRequired
Server = https://bstar.github.io/star-packages/$arch
```

The key's fingerprint is
`96D5 7784 6B2A 5540 6B65 41F8 8995 F50C E7BF C169`. It signs these packages
and nothing else.

To remove the repository, delete the `[star]` section and run
`sudo pacman-key --delete 96D577846B2A55406B6541F88995F50CE7BFC169`. Installed
apps stay installed; they just stop updating.

## What it serves

Only `x86_64`, and only the package attached to each app's latest **published**
GitHub release. Drafts and prereleases are never served. Nothing is built here:
[`scripts/build-repo.sh`](scripts/build-repo.sh) downloads each release's
package, checks it against that release's `SHA256SUMS`, signs it, and builds
the database with `repo-add`.

The [publish workflow](.github/workflows/publish.yml) runs daily and on demand.
When the package list hasn't changed, a daily run deploys nothing. Each deploy
ends with a fresh `archlinux` container that runs the setup script, installs
every app from the live repository, starts it and removes it again.

## AUR

[`aur/`](aur/) holds `-bin` recipes that repackage the same release artifacts,
for people who prefer the AUR. They are maintained here and published to the
AUR by hand.

## License

The scripts here are MIT licensed. Each package carries its app's own license.
