# Fluency canary

[![Hyprland main](https://github.com/larsoyd/fluency/actions/workflows/canary.yml/badge.svg?branch=canary)](https://github.com/larsoyd/fluency/actions/workflows/canary.yml)

Follows Hyprland `main` at [e826317](https://github.com/hyprwm/Hyprland/commit/e82631720b5d585d7ca09f567cb321063b7c7ab2), built on 2026-10-01.

This branch is for development. To use Fluency, install from [`main`](https://github.com/larsoyd/fluency/tree/main), which is built for the Hyprland your distribution ships.

## What it is

`canary` is Fluency kept working against Hyprland's development branch, so a change upstream that breaks the plugins or the Lua modules shows up here before it reaches a release and the users on `main`.

| | `main` | `canary` |
|---|---|---|
| Hyprland | the release Arch Linux, Debian sid and Fedora ship | `hyprwm/Hyprland` `main`, built from source |
| CI | install on the three distributions, weekly and on every push | build and verify against Hyprland `main`, daily and on every push |
| for | users | development |

## What the CI checks

`.github/workflows/canary.yml` runs every day and on each push to this branch. The schedule lives in the copy of the workflow on `main`, because GitHub only runs schedules from the default branch, and it always checks out `canary`.

1. `ci/canary/flake.nix` builds Hyprland from `main` (binaries from the Hyprland cachix) and gives a shell with its headers.
2. `ci/canary.sh` builds both plugins (`plugins/titlebar`, `plugins/minimize`) against those headers.
3. It runs `Hyprland --verify-config` on a config that only requires `hypr/fluency`.

Each step prints `[canary] stage=<name> result=ok|fail`. A failure opens an issue titled `canary failed on hyprland main <date>`, or comments on the one that is still open.

Run it locally with Nix:

```bash
nix develop ./ci/canary --no-write-lock-file -c ci/canary.sh .
```

## How changes move

- A feature lands on `main` first and is cherry-picked onto `canary`.
- A fix for an API change in Hyprland `main` is made on `canary` only. `main` keeps building against the release.
- When the distributions ship a new Hyprland release, `canary` is merged into `main` once the distribution CI is green on it, and the line at the top of this file and `main`'s README name the new versions.
- The commit named at the top is the last Hyprland `main` that built green here. It is updated after a green run against a newer commit.

## Installing it

`install.sh` is the same as on `main`. It needs a Hyprland built from `main` with its headers for the plugins, and Quickshell 0.3 or newer. Everything else is as described in `main`'s README.
