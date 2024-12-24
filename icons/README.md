<!--
SPDX-FileCopyrightText: Simon Schneegans <code@simonschneegans.de>
SPDX-License-Identifier: CC-BY-4.0
-->

# 🌸 Icons for Kando

This directory contains the sources for the icons used in Kando.
The `create.sh` script can be used on Linux and macOS to create all the icons for all platforms.
It requires `inkscape`, `svgo` and `imagaemagick` to be installed.
For the macOS icon, also `iconutil` is required.
Hence, the macOS icon can only be created on macOS.

The repository comes with a [dispatchable GitHub-Actions workflow](https://github.com/kando-menu/design/blob/main/.github/workflows/create-icons.yml) that runs this script and uploads the results as an artefact.
This runs on macOS, therefore the script is able to create all icons, including the macOS one.
