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
      params: {
        overrides: {
          removeUnusedNS: false,
        },
      },
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

# Scales a given SVG file to 256x256. This is done by adding a <g> element to the root of the
# SVG and scaling and translating the content.
normalize_size() {
    local svg="$1"

    if [[ -z "$svg" ]]; then
        echo "Usage: normalize_size <svg>"
        return 1
    fi

    # This ensures that every tag is on a new line.
    optimize_svg "$svg"

    local size=$(inkscape --query-width "$svg")
    local scale
    scale=$(echo "256 / $size" | bc -l)

    # Insert a <g> after the <svg> line using sed.
    sed -e "/^<svg.*/a\\
        <g transform=\"translate(0, 0) scale($scale) \">" "$svg" > "$TMP_DIR/tmp.svg"
    mv "$TMP_DIR/tmp.svg" "$svg"

    # Append the closing </g> tag before the final </svg> line using sed.
    sed -e '$i\'$'\n''</g>' "$svg" > "$TMP_DIR/tmp.svg"
    mv "$TMP_DIR/tmp.svg" "$svg"
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
    local scale
    scale=$(echo "($size - 2 * $margin) / $size" | bc -l)

    # Insert a <g> after the <svg> line using sed.
    sed -e "/^<svg.*/a\\
        <g transform=\"translate($margin, $margin) scale($scale) \">" "$svg" > "$TMP_DIR/tmp.svg"
    mv "$TMP_DIR/tmp.svg" "$svg"

    # Append the closing </g> tag before the final </svg> line using sed.
    sed -e '$i\'$'\n''</g>' "$svg" > "$TMP_DIR/tmp.svg"
    mv "$TMP_DIR/tmp.svg" "$svg"
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
    local base_margin="$4"
    local overlay_margin="$5"

    if [[ -z "$base_svg" || -z "$overlay_svg" || -z "$base_margin" || -z "$overlay_margin" || -z "$output_svg" ]]; then
        echo "Usage: composite_svgs <base_svg> <overlay_svg> <output_svg> <base_margin> <overlay_margin>"
        return 1
    fi

    cp "$base_svg" "$TMP_DIR/base.svg"
    cp "$overlay_svg" "$TMP_DIR/overlay.svg"

    # Normalize the size of the base and overlay SVGs.
    normalize_size "$TMP_DIR/base.svg"
    normalize_size "$TMP_DIR/overlay.svg"

    add_margin_to_svg "$TMP_DIR/base.svg" "$base_margin"
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
    local base_margin="$4"
    local overlay_margin="$5"
    local size="$6"

    if [[ -z "$base_svg" || -z "$overlay_svg" || -z "$output_png" || -z "$base_margin" || -z "$overlay_margin" || -z "$size" ]]; then
        echo "Usage: composite_svgs_and_save_as_png <base_svg> <overlay_svg> <output_png> <base_margin> <overlay_margin> <size>"
        return 1
    fi

    composite_svgs "$base_svg" "$overlay_svg" "$TMP_DIR/tmp.svg" "$base_margin" "$overlay_margin"
    convert_svg_to_png "$TMP_DIR/tmp.svg" "$output_png" "$size"
    rm "$TMP_DIR/tmp.svg"
}

# ----------------------------- Temporary Recolored Tiny and Small Icons ------------------------- # 

# We will use these icons multiple times, so we create temporary versions of them.

ICON=$(sed 's/path/path fill="#ffffff"/g' < source/blossom_tiny.svg)
echo "$ICON" > "$TMP_DIR/blossom_tiny_white.svg"
ICON=$(sed 's/path/path fill="#f0cece"/g' < source/blossom_tiny.svg)
echo "$ICON" > "$TMP_DIR/blossom_tiny_light.svg"
ICON=$(sed 's/path/path fill="#24272f"/g' < source/blossom_tiny.svg)
echo "$ICON" > "$TMP_DIR/blossom_tiny_dark.svg"
ICON=$(sed 's/path/path fill="#000000"/g' < source/blossom_tiny.svg)
echo "$ICON" > "$TMP_DIR/blossom_tiny_black.svg"

ICON=$(sed 's/path/path fill="#ffffff"/g' < source/blossom_small.svg)
echo "$ICON" > "$TMP_DIR/blossom_small_white.svg"
ICON=$(sed 's/path/path fill="#f0cece"/g' < source/blossom_small.svg)
echo "$ICON" > "$TMP_DIR/blossom_small_light.svg"
ICON=$(sed 's/path/path fill="#24272f"/g' < source/blossom_small.svg)
echo "$ICON" > "$TMP_DIR/blossom_small_dark.svg"
ICON=$(sed 's/path/path fill="#000000"/g' < source/blossom_small.svg)
echo "$ICON" > "$TMP_DIR/blossom_small_black.svg"

# ------------------------------------------ Tray Icons ------------------------------------------ #

echo "Creating tray icons..."

# First, we create the tray icons for macOS. This requires three sizes: 16x16, 32x32, and 64x64.
convert_svg_to_png "source/blossom_tiny.svg" "$OUTPUT_DIR/trayTemplate.png"    16
convert_svg_to_png "source/blossom_tiny.svg" "$OUTPUT_DIR/trayTemplate@2x.png" 32
convert_svg_to_png "source/blossom_tiny.svg" "$OUTPUT_DIR/trayTemplate@4x.png" 64

# Then we need four versions of the tray icon.
convert_svg_to_png "$TMP_DIR/blossom_tiny_white.svg" "$OUTPUT_DIR/trayWhite.png" 64
convert_svg_to_png "$TMP_DIR/blossom_tiny_light.svg" "$OUTPUT_DIR/trayLight.png" 64
convert_svg_to_png "$TMP_DIR/blossom_tiny_dark.svg"  "$OUTPUT_DIR/trayDark.png"  64
convert_svg_to_png "$TMP_DIR/blossom_tiny_black.svg" "$OUTPUT_DIR/trayBlack.png" 64

# For the colored tray icon, we overlay the light variant onto bg_tiny_square.svg.
composite_svgs source/bg_tiny_square.svg $TMP_DIR/blossom_tiny_light.svg $TMP_DIR/trayColor.svg 0 24
convert_svg_to_png "$TMP_DIR/trayColor.svg" "$OUTPUT_DIR/trayColor.png" 64

# ------------------------------------------ Favicon --------------------------------------------- #

echo "Creating favicon..."

# For the browser favicon, we overlay the light small variant onto bg_tiny_square.svg.
composite_svgs source/bg_tiny_square.svg $TMP_DIR/blossom_small_light.svg $OUTPUT_DIR/favicon.svg 0 24

# --------------------------------------- Homepage Icon ------------------------------------------ #

echo "Creating homepage icon..."

# The homepage icon is an SVG made from blossom_medium.svg on top of bg_square.svg.
composite_svgs source/bg_square.svg source/blossom_medium.svg $OUTPUT_DIR/web-icon.svg 16 32


# ---------------------------------------- Linux Icon -------------------------------------------- #

echo "Creating Linux icon..."

# The Linux icon is an SVG made from blossom_medium.svg on top of bg_circle.svg.
composite_svgs source/bg_circle.svg source/blossom_medium.svg $OUTPUT_DIR/icon.svg 16 32

# We also need a png version of the icon.
convert_svg_to_png "$OUTPUT_DIR/icon.svg" "$OUTPUT_DIR/icon.png" 0 512


# ---------------------------------------- Windows Icon ------------------------------------------ #

echo "Creating Windows icon..."

# The Windows icon contains various sizes of all the blossom icons on top of bg_circle.svg.
WIN_TMP_DIR=$TMP_DIR/win
mkdir -p $WIN_TMP_DIR

# Create PNGs at different sizes.
composite_svgs_and_save_as_png source/bg_circle.svg $TMP_DIR/blossom_tiny_light.svg "$WIN_TMP_DIR/16.png"  0 20 16
composite_svgs_and_save_as_png source/bg_circle.svg $TMP_DIR/blossom_small_light.svg "$WIN_TMP_DIR/32.png" 0 20 32
composite_svgs_and_save_as_png source/bg_circle.svg source/blossom_medium.svg "$WIN_TMP_DIR/48.png" 0 20 48
composite_svgs_and_save_as_png source/bg_circle.svg source/blossom_medium.svg "$WIN_TMP_DIR/64.png" 0 20 64
composite_svgs_and_save_as_png source/bg_circle.svg source/blossom_large.svg "$WIN_TMP_DIR/96.png"  0 19 96
composite_svgs_and_save_as_png source/bg_circle.svg source/blossom_large.svg "$WIN_TMP_DIR/128.png" 0 19 128
composite_svgs_and_save_as_png source/bg_circle.svg source/blossom_large.svg "$WIN_TMP_DIR/256.png" 0 19 256

convert \
  "$WIN_TMP_DIR/16.png" \
  "$WIN_TMP_DIR/32.png" \
  "$WIN_TMP_DIR/48.png" \
  "$WIN_TMP_DIR/64.png" \
  "$WIN_TMP_DIR/96.png" \
  "$WIN_TMP_DIR/128.png" \
  "$WIN_TMP_DIR/256.png" \
  "$OUTPUT_DIR/icon.ico"


# ---------------------------------------- Mac Icon ---------------------------------------------- #

echo "Creating macOS icon..."

# The macOS icon is an icns file containing various sizes of the blossom icons on top of bg_square.svg.
MAC_TMP_DIR=$TMP_DIR/icon.iconset
mkdir -p $MAC_TMP_DIR

# Create PNGs at different sizes.
composite_svgs_and_save_as_png source/bg_square.svg $TMP_DIR/blossom_tiny_light.svg "$MAC_TMP_DIR/icon_16x16.png"     16 40 16
composite_svgs_and_save_as_png source/bg_square.svg $TMP_DIR/blossom_small_light.svg "$MAC_TMP_DIR/icon_16x16@2x.png" 16 36 32
composite_svgs_and_save_as_png source/bg_square.svg $TMP_DIR/blossom_small_light.svg "$MAC_TMP_DIR/icon_32x32.png"    16 36 32
composite_svgs_and_save_as_png source/bg_square.svg source/blossom_medium.svg "$MAC_TMP_DIR/icon_32x32@2x.png"  24 40 64
composite_svgs_and_save_as_png source/bg_square.svg source/blossom_medium.svg "$MAC_TMP_DIR/icon_128x128.png"   24 40 128
composite_svgs_and_save_as_png source/bg_square.svg source/blossom_large.svg "$MAC_TMP_DIR/icon_128x128@2x.png" 24 40 256
composite_svgs_and_save_as_png source/bg_square.svg source/blossom_large.svg "$MAC_TMP_DIR/icon_256x256.png"    24 40 256
composite_svgs_and_save_as_png source/bg_square.svg source/blossom_large.svg "$MAC_TMP_DIR/icon_256x256@2x.png" 24 40 512
composite_svgs_and_save_as_png source/bg_square.svg source/blossom_large.svg "$MAC_TMP_DIR/icon_512x512.png"    24 40 512
composite_svgs_and_save_as_png source/bg_square.svg source/blossom_large.svg "$MAC_TMP_DIR/icon_512x512@2x.png" 24 40 1024

# Create the icns file. If the iconutil command is not available, we print a warning and skip this step.
if command -v iconutil >/dev/null 2>&1; then
    iconutil -c icns -o "$OUTPUT_DIR/icon.icns" "$MAC_TMP_DIR"
else
    echo "Warning: iconutil is not available. Skipping creation of macOS icon."
fi


# --------------------------------------- Social Icon -------------------------------------------- #

echo "Creating social icon..."

# The social icon is an SVG made from blossom_medium.svg on top of bg_full.svg.
composite_svgs source/bg_full.svg source/blossom_medium.svg $OUTPUT_DIR/social.svg 0 32

# We also need a png version of the icon.
convert_svg_to_png "$OUTPUT_DIR/social.svg" "$OUTPUT_DIR/social.png" 512

# ----------------------------------------- Done! ------------------------------------------------ #

echo "Done! Icons have been created and saved to the output directory."
