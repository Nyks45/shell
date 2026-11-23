# Desktop widgets: credits

The desktop widgets (`widgets/`), the glass cards and shapes, and the lock screen
(`modules/lock/`) are based on **Nebula** by LilaccFlowerr
(https://github.com/LilaccFlowerr/Nebula, commit 9749c30), licensed under the GNU Affero
General Public License v3.0 (`widgets/LICENSE`). Those parts remain under the AGPL-3.0.

- `widgets/`: the desktop widgets with their menus, settings pages, services and theme
  (`qs.widgets.*`). Adapted to Caelestia: colours from the shell's scheme
  (`theme/Colors.qml`), fonts and glass from the shell's settings (`theme/Theme.qml`), the
  clock format, weather location and low-battery level from the shell's own settings, files
  under the shell's config/cache dirs (`~/.config/caelestia/widgets`), layer namespaces
  `caelestia-widgets-*`, IPC targets `desktopWidgets`, settings pages inside the shell's
  settings app (Settings › Wallpaper & style › Desktop). Everything of the original that
  the shell doesn't use was removed (its own bar, launcher, dock, popups, notifications,
  media panel, recorder, screenshots, wallpaper switching, colour schemes and Hyprland
  settings).
- `modules/desktopwidgets/`: where the shell loads the widgets.
- `modules/nexus/pages/style/DesktopWidgetPages.qml`: hosts the widgets' settings pages.
- `modules/lock/`: the lock screen (a separate, earlier port).
- The Plymouth boot theme (`assets/plymouth-nebula`) keeps its original name.
