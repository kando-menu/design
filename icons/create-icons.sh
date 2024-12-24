#!/bin/bash

# SPDX-FileCopyrightText: Simon Schneegans <code@simonschneegans.de>
# SPDX-License-Identifier: MIT

# ------------------------------------------------------------------------------------------------ #
# This script creates various icons for Kando. For this it overlays different blossom variants on  #
# top of different background images. The resulting icons are saved in the output directory.       #
#                                                                                                  #
# Layering SVGs ontop of each other is surprisingly difficult. The main problem is that the SVG    #
# files contain IDs for each element. If we simply overlay two SVGs, the IDs will clash. To solve  #
# this problem, we use the svgo tool to prefix all IDs with a unique string. Also, the overlayed   #
# SVGs need to be scaled and translated to fit the background. This is done by adding a <g>        #
# element to the root of the SVG.                                                                  #
#                                                                                                  #
# You will need to have svgo, inkscape, and convert from ImageMagick installed. To create the      #
# macOS icon, you will need to run this script on a macOS machine.                                 #
# ------------------------------------------------------------------------------------------------ #

# Exit on error.
set -e

# Change to the directory of this script.
cd "$(dirname "$0")"

# Create a temporary build directory.
TMP_DIR=tmp
mkdir -p $TMP_DIR

# Create the output directory.
OUTPUT_DIR=output
mkdir -p $OUTPUT_DIR

# Ensure dependencies exist.
command -v svgo >/dev/null 2>&1 || { echo "Error: svgo is required but not installed."; return 1; }
command -v inkscape >/dev/null 2>&1 || { echo "Error: inkscape is required but not installed."; return 1; }
command -v convert >/dev/null 2>&1 || { echo "Error: convert from image magick is required but not installed."; return 1; }

# ------------------------------------------ Functions ------------------------------------------- #

# Optimize an SVG file using svgo. It prefixes all IDs with a unique string. It also ensures that
# every tag is on a new line.
optimize_svg() {
    local svg="$1"

    if [[ -z "$svg" ]]; then
        echo "Usage: optimize_svg <svg> "
        return 1
    fi

    PREFIX=$(basename "$svg" .svg)

    # Write custom configuration for svgo.
    cat >$TMP_DIR/svgo.config.js <<EOL
module.exports = {
  plugins: [
    {
      name: "preset-default",
    },
    {
      name: "prefixIds",
      params: {
        delim: "",
        prefix: "$PREFIX",
      },
    },
  ],
};
EOL

    svgo --quiet --pretty --indent 0 --final-newline --input "$svg" --output "$svg" --config=$TMP_DIR/svgo.config.js

    # Remove temporary configuration file.
    rm "$TMP_DIR/svgo.config.js"
}

# Adds a margin to an SVG file. This is done by adding a <g> element to the root of the SVG and
# scaling and translating the content. This function assumes that the SVG file has a size of 256x256.
add_margin_to_svg() {
    local svg="$1"
    local margin="$2"

    if [[ -z "$svg" || -z "$margin" ]]; then
        echo "Usage: add_margin_to_svg <svg> <margin>"
        return 1
    fi

    # This ensures that every tag is on a new line.
    optimize_svg "$svg"

    local size=256
    local scale=$(echo "($size - 2 * $margin) / $size" | bc -l)

    # Insert a <g> after the <svg> line using sed.
    sed -i "/^<svg.*/a <g transform=\"translate($margin, $margin) scale($scale) \">" "$svg"

    # Append the closing </g> tag before the final </svg> line using sed.
    sed -i '$i </g>' "$svg"
}

# Converts an SVG to a PNG of the specified size.
convert_svg_to_png() {
    local input_svg="$1"
    local output_png="$2"
    local size="$3"

    if [[ -z "$input_svg" || -z "$output_png" || -z "$size" ]]; then
        echo "Usage: convert_svg_to_png <input_svg> <output_png> <size>"
        return 1
    fi

    inkscape -w "$size" -h "$size" "$input_svg" -o "$output_png"
}

# Function to composite two SVGs into a single SVG. The first SVG is used as the base, the second
# SVG is overlayed on top of it. Both SVGs must have a size of 256x256 pixels. You can specify a
# margin for the overlay SVG. This is given in pixels.
composite_svgs() {
    local base_svg="$1"
    local overlay_svg="$2"
    local output_svg="$3"
    local overlay_margin="$4"

    if [[ -z "$base_svg" || -z "$overlay_svg" || -z "$overlay_margin" || -z "$output_svg" ]]; then
        echo "Usage: composite_svgs <base_svg> <overlay_svg> <output_svg> <overlay_margin>"
        return 1
    fi

    cp "$base_svg" "$TMP_DIR/base.svg"
    cp "$overlay_svg" "$TMP_DIR/overlay.svg"

    add_margin_to_svg "$TMP_DIR/overlay.svg" "$overlay_margin"

    # Optimize the base and overlay SVGs.
    optimize_svg "$TMP_DIR/base.svg"
    optimize_svg "$TMP_DIR/overlay.svg"

    # Append the overlay SVG to the base SVG.
    grep --invert-match "</svg>" "$TMP_DIR/base.svg" > "$output_svg"
    grep --invert-match "<svg" "$TMP_DIR/overlay.svg" >> "$output_svg"
}

# Same as composite_svgs, but also converts the result to a PNG of the specified size.
composite_svgs_and_save_as_png() {
    local base_svg="$1"
    local overlay_svg="$2"
    local output_png="$3"
    local overlay_margin="$4"
    local size="$5"

    if [[ -z "$base_svg" || -z "$overlay_svg" || -z "$output_png" || -z "$overlay_margin" || -z "$size" ]]; then
        echo "Usage: composite_svgs_and_save_as_png <base_svg> <overlay_svg> <output_png> <overlay_margin> <size>"
        return 1
    fi

    composite_svgs "$base_svg" "$overlay_svg" "$TMP_DIR/tmp.svg" "$overlay_margin"
    convert_svg_to_png "$TMP_DIR/tmp.svg" "$output_png" "$size"
    rm "$TMP_DIR/tmp.svg"
}


# ------------------------------------------ Tray Icons ------------------------------------------ #

echo "Creating tray icons..."

# First, we create the tray icons for macOS. This requires three sizes: 16x16, 32x32, and 64x64.
# All icons need to be black as they will be recolored by the system.

# We start by loading source/blossom_tiny.svg and replace the #f0cece color with black. We store
# the result in $TMP_DIR/blossom_tiny_black.svg.
ICON=$(cat source/blossom_tiny.svg | sed 's/#f0cece/#000000/g')
echo "$ICON" > "$TMP_DIR/blossom_tiny_black.svg"

convert_svg_to_png "$TMP_DIR/blossom_tiny_black.svg" "$OUTPUT_DIR/trayTemplate.png" 16
convert_svg_to_png "$TMP_DIR/blossom_tiny_black.svg" "$OUTPUT_DIR/trayTemplate@2x.png" 32
convert_svg_to_png "$TMP_DIR/blossom_tiny_black.svg" "$OUTPUT_DIR/trayTemplate@4x.png" 64
rm "$TMP_DIR/blossom_tiny_black.svg"

# Then we need a light version of the tray icon and a dark version. The light version is simply
# blossom_tiny.svg, for the dark version we replace #f0cece with #24272f.
convert_svg_to_png source/blossom_tiny.svg "$OUTPUT_DIR/tray-light.png" 64
ICON=$(cat source/blossom_tiny.svg | sed 's/#f0cece/#24272f/g')
echo "$ICON" > "$TMP_DIR/blossom_tiny_dark.svg"
convert_svg_to_png "$TMP_DIR/blossom_tiny_dark.svg" "$OUTPUT_DIR/tray-dark.png" 64
rm "$TMP_DIR/blossom_tiny_dark.svg"

# For the colored tray icon, we overlay the blossom_tiny.svg onto the bg_tiny_square.svg.
composite_svgs source/bg_tiny_square.svg source/blossom_tiny.svg $TMP_DIR/tray-colored.svg 24
convert_svg_to_png "$TMP_DIR/tray-colored.svg" "$OUTPUT_DIR/tray-colored.png" 64


# ------------------------------------------ Favicon --------------------------------------------- #

echo "Creating favicon..."

# For the browser favicon, we overlay the blossom_small.svg onto the bg_tiny_square.svg.
composite_svgs source/bg_tiny_square.svg source/blossom_small.svg $OUTPUT_DIR/favicon.svg 24


# ---------------------------------------- Linux Icon -------------------------------------------- #

echo "Creating Linux icon..."

# The Linux icon is an SVG made from blossom_medium.svg on top of bg_circle.svg.
composite_svgs source/bg_circle.svg source/blossom_medium.svg $OUTPUT_DIR/icon.svg 32

# We also need a png version of the icon.
convert_svg_to_png "$OUTPUT_DIR/icon.svg" "$OUTPUT_DIR/icon.png" 512


# ---------------------------------------- Windows Icon ------------------------------------------ #

echo "Creating Windows icon..."

# The Windows icon contains various sizes of all the blossom icons on top of bg_circle.svg.
WIN_TMP_DIR=$TMP_DIR/win
mkdir -p $WIN_TMP_DIR

# Create PNGs at different sizes.
composite_svgs_and_save_as_png source/bg_circle.svg source/blossom_tiny.svg "$WIN_TMP_DIR/16.png" 32 16
composite_svgs_and_save_as_png source/bg_circle.svg source/blossom_small.svg "$WIN_TMP_DIR/32.png" 32 32
composite_svgs_and_save_as_png source/bg_circle.svg source/blossom_medium.svg "$WIN_TMP_DIR/48.png" 32 48
composite_svgs_and_save_as_png source/bg_circle.svg source/blossom_medium.svg "$WIN_TMP_DIR/64.png" 32 64
composite_svgs_and_save_as_png source/bg_circle.svg source/blossom_large.svg "$WIN_TMP_DIR/96.png" 32 96
composite_svgs_and_save_as_png source/bg_circle.svg source/blossom_large.svg "$WIN_TMP_DIR/256.png" 32 256

convert \
  "$WIN_TMP_DIR/16.png" \
  "$WIN_TMP_DIR/32.png" \
  "$WIN_TMP_DIR/48.png" \
  "$WIN_TMP_DIR/64.png" \
  "$WIN_TMP_DIR/96.png" \
  "$WIN_TMP_DIR/256.png" \
  "$OUTPUT_DIR/icon.ico"


# ---------------------------------------- Mac Icon ---------------------------------------------- #

echo "Creating macOS icon..."

# The macOS icon is an icns file containing various sizes of the blossom icons on top of bg_square.svg.
MAC_TMP_DIR=$TMP_DIR/icon.iconset
mkdir -p $MAC_TMP_DIR

# Create PNGs at different sizes.
composite_svgs_and_save_as_png source/bg_square.svg source/blossom_tiny.svg "$MAC_TMP_DIR/icon_16x16.png" 40 16
composite_svgs_and_save_as_png source/bg_square.svg source/blossom_small.svg "$MAC_TMP_DIR/icon_16x16@2x.png" 36 32
composite_svgs_and_save_as_png source/bg_square.svg source/blossom_small.svg "$MAC_TMP_DIR/icon_32x32.png" 36 32
composite_svgs_and_save_as_png source/bg_square.svg source/blossom_medium.svg "$MAC_TMP_DIR/icon_32x32@2x.png" 32 64
composite_svgs_and_save_as_png source/bg_square.svg source/blossom_medium.svg "$MAC_TMP_DIR/icon_128x128.png" 32 128
composite_svgs_and_save_as_png source/bg_square.svg source/blossom_large.svg "$MAC_TMP_DIR/icon_128x128@2x.png" 32 256
composite_svgs_and_save_as_png source/bg_square.svg source/blossom_large.svg "$MAC_TMP_DIR/icon_256x256.png" 32 256
composite_svgs_and_save_as_png source/bg_square.svg source/blossom_large.svg "$MAC_TMP_DIR/icon_256x256@2x.png" 32 512
composite_svgs_and_save_as_png source/bg_square.svg source/blossom_large.svg "$MAC_TMP_DIR/icon_512x512.png" 32 512
composite_svgs_and_save_as_png source/bg_square.svg source/blossom_large.svg "$MAC_TMP_DIR/icon_512x512@2x.png" 32 1024

# Create the icns file. If the iconutil command is not available, we print a warning and skip this step.
if command -v iconutil >/dev/null 2>&1; then
    iconutil -c icns "$MAC_TMP_DIR"
else
    echo "Warning: iconutil is not available. Skipping creation of macOS icon."
fi


# --------------------------------------- Social Icon -------------------------------------------- #

echo "Creating social icon..."

# The social icon is an SVG made from blossom_medium.svg on top of bg_full.svg.
composite_svgs source/bg_full.svg source/blossom_medium.svg $OUTPUT_DIR/social.svg 32

# We also need a png version of the icon.
convert_svg_to_png "$OUTPUT_DIR/social.svg" "$OUTPUT_DIR/social.png" 512

# ----------------------------------------- Done! ------------------------------------------------ #

echo "Done! Icons have been created and saved to the output directory."
