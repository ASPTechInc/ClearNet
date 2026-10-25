# Contributing to ClearNet

Thanks for your interest in contributing to **ClearNet**!
ClearNet is a free and open-source (FOSS) content-control app and contributions of all sizes are welcome.

---

## How to Contribute

1. **Fork the repository** to your own GitHub account.
2. **Clone your fork** to your local machine.
3. **Create a new branch** for your work:
   ```bash
   git checkout -b feature/your-feature-name
   ```
4. **Make your changes**, following the code style below.
5. **Run the tests** and check they still pass.
6. **Commit your changes** with messages that say what changed and why.
7. **Push to your fork**:
   ```bash
   git push origin feature/your-feature-name
   ```
8. **Create a pull request** from your fork's branch to the `main` branch of the original repository.

---

## Technical Stack

ClearNet is built with Flutter, with native Android code in Kotlin:

- **Language**: [Dart](https://dart.dev/)
- **Framework**: [Flutter SDK](https://flutter.dev/)
- **Android services**: [Kotlin](https://kotlinlang.org/) (VPN, accessibility service and device administrator)
- **Default blocklist**: `assets/data/blocklist.json`

---

## Code Style

- **Formatting**: Run `dart format .` before committing changes.
- **Linting**: `flutter analyze` should report no issues.
- **Scope**: Keep each pull request to one feature or bug fix.

---

## Testing

Please add or update tests when you change how blocking or filtering works.

### Run the test suite

```bash
flutter test
```

---

## Reporting Issues

If you find a bug or have a feature request, please [open an issue](https://github.com/ASPTechInc/ClearNet/issues).
