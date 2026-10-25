# [v1.0.0](https://github.com/ASPTechInc/ClearNet/tree/v1.0.0) (2026-10-13)

First stable release of ClearNet, a free and open-source (FOSS) content-control app built with Flutter.

### Features

- Uninstall protection: ClearNet registers as a device administrator and cannot be uninstalled
  without the PIN. Device administrator access is requested when the uninstall PIN is set,
  Settings shows whether protection is active and ClearNet asks again if access is turned off.
- App blocking: chosen apps are closed when they're opened.
- Website blocking: a local VPN filters DNS lookups against a built-in blocklist of adult domains.
- Browser checks: blocked domains and keywords shown in any web browser open the blocked page.
  These checks keep working when another VPN app is on.
- Custom blocklists: add your own domains, keywords and allowed sites.
- Blocklist import and export as a `.backup` file for backup and restore.
- SafeSearch: Google, Bing and YouTube are redirected to their SafeSearch addresses.
- Custom DNS server (e.g. Quad9).
- A notification when another VPN app turns website filtering off.
- App disguise: show ClearNet as a Calculator or Notes app on the home screen.
- App lock: an 8 to 16 digit app PIN, asked for again after you leave ClearNet (immediately, after
  1 minute or after 5 minutes).
- Forgotten app PIN: reset it with the uninstall PIN or, if none is set, after a 24-hour wait.
- The app PIN and uninstall PIN must be different.
- Settings PIN lock.
- Confirmation challenge before blocking can be turned off: three sentences of hard words, with
  no word repeated.
- Daily, weekly and monthly counts of blocked websites and apps.
- Light, dark and system themes.
- In-app changelog, source code link, donation link and GitHub update checker.
- No accounts, analytics or adverts. Released under the MIT licence.
