# Privacy policy

Last updated: 09-09-2026

ClearNet is a free and open source software (FOSS) parental control application built with Flutter.
This privacy policy explains what data the app handles and how.

## Summary

- ClearNet does not require account sign-in or remote credentials.
- ClearNet does not host any metrics analytics or advertising trackers.
- ClearNet stores configuration preferences and parent filters locally on your device.
- The app operates entirely offline for filtering; no traffic is transmitted to external cloud systems.

## Data we process

ClearNet stores configuration rules locally on the device using secure platform-native storage (`shared_preferences` and `flutter_secure_storage`), such as:
- Parent security PIN configurations.
- App restriction rules.
- Custom appended domain lists.

## Data sharing

ClearNet does not transmit your private network metadata or configurations to external servers. All traffic filtering occurs strictly locally using Android's native `VPNService` capabilities.

## Permissions

ClearNet requires the following permissions to operate:
- **Device Administrator**: Used strictly to safeguard the app against unauthorized deletion.
- **VPN Service**: Used to loop network packets locally to block harmful adult domains completely offline.

## Open source transparency

You can inspect the source code to verify data handling behaviour because ClearNet is FOSS:
- Repository: https://github.com/ASPTechInc/ClearNet

## Changes to this policy

This policy may be updated over time to reflect app changes. The latest version is always kept in the official repository.
