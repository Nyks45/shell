# Parts from Nebula

Parts of this shell come from **Nebula** by LilaccFlowerr
(https://github.com/LilaccFlowerr/Nebula, commit 9749c30), licensed under the GNU Affero
General Public License v3.0 (`nebula/LICENSE`). Those parts remain under the AGPL-3.0.

- `nebula/`: Nebula's shell, nearly unchanged, used as a module (`qs.nebula.*`). Changes made
  for the integration: imports renamed to `qs.nebula.*`; colours taken from the shell's scheme
  (`theme/Colors.qml`); fonts and glass tokens from the shell's settings (`theme/Theme.qml`);
  files under the shell's own config/state/cache dirs; layer namespaces `caelestia-nebula-*`;
  IPC targets prefixed `nebula*`; Nebula's settings for its parts open in the shell's settings
  app (Settings > Style); the widgets share the desktop with the shell's desktop icons.
- `modules/nebula/`: where the shell loads Nebula's parts (each one an option under
  Settings > Style).
- `modules/nexus/pages/style/`: the Style page, and the host for Nebula's own settings pages.
- `modules/lock/`: the lock screen (an earlier, separate port).

Turned on so far: desktop widgets. The bar, launcher, dock/taskbar, popups, notification
galaxy, media panel and equalizer follow (plan: `dev/plans/nebula-integration.md`).
