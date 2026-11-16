# Parts from Nebula

Parts of this shell come from **Nebula** by LilaccFlowerr
(https://github.com/LilaccFlowerr/Nebula, commit 9749c30), licensed under the GNU Affero
General Public License v3.0 (`nebula/LICENSE`). Those parts remain under the AGPL-3.0.

- `nebula/`: the parts of Nebula's shell this shell uses (its desktop widgets with their
  menus, settings pages, services and theme), nearly unchanged, as a module (`qs.nebula.*`). Changes made
  for the integration: imports renamed to `qs.nebula.*`; colours taken from the shell's scheme
  (`theme/Colors.qml`); fonts and glass tokens from the shell's settings (`theme/Theme.qml`);
  files under the shell's own config/state/cache dirs; layer namespaces `caelestia-nebula-*`;
  IPC targets prefixed `nebula*`; Nebula's settings for its parts open in the shell's settings
  app (Settings > Style); the widgets share the desktop with the shell's desktop icons.
- `modules/nebula/`: where the shell loads Nebula's parts (each one an option under
  Settings > Style).
- `modules/nexus/pages/style/`: the Style page, and the host for Nebula's own settings pages.
- `modules/lock/`: the lock screen (an earlier, separate port).

Only the desktop widgets are used (2026-11-16: the user dropped the rest; the bar, launcher,
dock, popups, notification galaxy, media panel, recorder and screenshot parts were removed).
The lock screen and boot animation are separate ports and stay.
