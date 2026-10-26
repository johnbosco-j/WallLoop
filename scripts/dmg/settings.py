# dmgbuild settings for WallLoop's DMG window. scripts/release.sh passes the paths with -D:
#   app=<path to WallLoop.app>  background=<HiDPI TIFF>  icon=<volume .icns>
# The layout matches DMGBackground in scripts/BrandRenderer.swift (a 660 × 420 canvas with
# the app at (170, 205) and Applications at (490, 205)). Re-render it with
# scripts/render-brand.sh after changing either.
import os.path

app = defines["app"]  # noqa: F821 (provided by dmgbuild)
app_name = os.path.basename(app)

format = "UDZO"
compression_level = 9
filesystem = "HFS+"

files = [app]
symlinks = {"Applications": "/Applications"}
hide_extensions = [app_name]

icon = defines.get("icon")  # noqa: F821
background = defines["background"]  # noqa: F821

# Finder window: no toolbar, sidebar or status bar; the frame includes a ~28 pt title bar.
window_rect = ((200, 140), (660, 448))
default_view = "icon-view"
show_status_bar = False
show_tab_view = False
show_toolbar = False
show_pathbar = False
show_sidebar = False
show_icon_preview = False
include_icon_view_settings = True

arrange_by = None
icon_size = 128
text_size = 13
label_pos = "bottom"
icon_locations = {
    app_name: (170, 205),
    "Applications": (490, 205),
}
