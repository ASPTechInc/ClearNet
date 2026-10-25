# Privacy policy

Last updated: 13-10-2026

ClearNet is a free and open source (FOSS) content-control app built with Flutter.
This policy explains what data the application handles and where it goes.

## Summary

- ClearNet has no accounts, analytics, adverts or trackers.
- Your settings, lists and PINs are stored only on your device.
- Blocked websites are blocked on the device. To load allowed websites, ClearNet sends DNS lookups to a DNS server (see "Network connections" below).

## Data stored on your device

ClearNet stores the following using `shared_preferences` and `flutter_secure_storage`:

- The app lock PIN and uninstall PIN, stored only as salted hashes in Android's encrypted storage. The PINs themselves are never saved.
- Blocked apps, blocked websites, blocked keywords and allowed (whitelisted) websites
- Counts of how many websites and apps were blocked each day, week and month. ClearNet does not record which websites or apps were blocked.
- Settings such as theme, app disguise and custom DNS server

None of this data leaves your device unless you export your blocklist yourself.

## Network connections

ClearNet does not send your data to its developers or to any server it runs. It makes these connections:

- **DNS lookups:** when the VPN is on, ClearNet answers lookups for blocked domains on the device. Other lookups are forwarded to your chosen DNS server or by default to UncensoredDNS, AdGuard DNS or Quad9. Those providers can see which domain names your device looks up, under their privacy policies.
- **SafeSearch:** lookups for Google, Bing and YouTube are answered with their SafeSearch addresses.
- **Update check:** only when you tap "Check updates" in Settings, ClearNet asks the GitHub API for the latest release version. This option is not shown in F-Droid builds.
- **Links:** the source code, licence and donation links open GitHub or Buy Me a Coffee in a browser view.

## Permissions

- **Internet:** used for the connections listed under "Network connections" above.
- **VPN service:** used to filter DNS lookups as described above. ClearNet does not route your general traffic through a remote VPN server.
- **Run at startup:** used to start the VPN again after the device restarts or ClearNet is updated, if blocking was on.
- **Accessibility service:** used to detect which app is open so blocked apps can be closed. In web browsers, ClearNet also reads the text on screen, such as the address bar and checks it against your blocked keywords and domains. To recognise browsers, ClearNet asks Android which installed apps can open web links; this list stays on the device. If an uninstall PIN is set, ClearNet also checks screens in the Settings app for its own device administrator and accessibility pages, so they cannot be used to remove it without the PIN. These checks happen on the device. Screen content is not stored or sent anywhere.
- **Device administrator:** requested when you set an uninstall PIN and used to stop ClearNet being uninstalled or switched off without the PIN. ClearNet does not use it to wipe, lock or reset your device.
- **Notifications:** used only to tell you when another VPN app has turned website filtering off. The notification does not name ClearNet, so it doesn't give away a disguised icon.
- **Ignore battery optimisations:** used so Android does not stop the filtering service in the background.

## Open source

You can read the source code to check how ClearNet handles data:
https://github.com/ASPTechInc/ClearNet

## Changes to this policy

This policy is updated when the app's data handling changes. The latest version is in the repository.
