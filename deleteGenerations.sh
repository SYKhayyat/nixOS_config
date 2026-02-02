#!/usr/bin/env bash
nix-collect-garbage -d
nixos-rebuild boot --flake
nix-collect-garbage
