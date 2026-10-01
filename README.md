# Fluency canary

[![Canary](https://github.com/larsoyd/fluency/actions/workflows/canary.yml/badge.svg?branch=canary)](https://github.com/larsoyd/fluency/actions/workflows/canary.yml)
[![Hyprland main](https://img.shields.io/endpoint?url=https%3A%2F%2Fraw.githubusercontent.com%2Flarsoyd%2Ffluency%2Fbadges%2Fcanary.json)](https://github.com/larsoyd/fluency/actions/workflows/canary.yml)

The badge shows the Hyprland `main` commit of the last canary run and the day it ran, green when everything built and red when something failed.

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
4. It writes the result to `canary.json` on the `badges` branch, which the badge at the top reads. That branch holds a single commit that every run replaces.

Each step prints `[canary] stage=<name> result=ok|fail`. A failure opens an issue titled `canary failed on hyprland main <date>`, or comments on the one that is still open.

Run it locally with Nix:

```bash
nix develop ./ci/canary --no-write-lock-file -c ci/canary.sh .
```

## Temporary compatibility

When Hyprland `main` changes an API like plugins use or anything else, the fix goes onto both branches, so `canary` and `main` build the same plugin sources. Each affected source gets a special compatibility layer like `compat.hpp` for one example that checks for a header only the newer Hyprland has, uses the new API or any other changes when that header is there and falls back to the old code when it is not. Every fallback sits under the comment

```cpp
// TODO: temporary compat maintained for a few months after release then removed
```

and is removed a few months after the Hyprland release that has the change reaches the distributions. Searching for that comment finds every fallback still in place.

## How changes move

- A feature lands on `main` first and is cherry-picked onto `canary`.
- A fix for an API change in Hyprland `main` goes onto both branches behind the temporary compatibility above, so `main` keeps building against the release.
- When the distributions ship a new Hyprland release, then any changes not already merged in `canary` which are compatible with it are merged into `main` once the distribution CI is green on it, and `main`'s README names the new version. `canary` itself as a branch stays consistent and isn’t merged wholesale.

  

## Installing it

`install.sh` is the same as on `main`. It needs a Hyprland built from `main` with its headers for the plugins, and Quickshell 0.3 or newer. Everything else is as described in `main`'s README.
