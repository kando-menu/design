<!--
SPDX-FileCopyrightText: Simon Schneegans <code@simonschneegans.de>
SPDX-License-Identifier: CC-BY-4.0
-->

# Notes

The `blossom_medium_clipped.svg` is visually identical to `blossom_medium.svg`, but the petals are shaped by a clipping path.
This makes it much easier to edit the shape of the petals.
So if you want to change the shape of the petals, you should edit `blossom_medium_clipped.svg` and then apply the clipping path and save the result as `blossom_medium.svg`.

We cannot use the clipped version directly, as KDE and maybe some other desktop environments do not support clipping paths in SVG icons.
