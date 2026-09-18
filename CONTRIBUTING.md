# Contributing to ClearNet

Thanks for your interest in contributing to **ClearNet**!
ClearNet is a free open source (FOSS) parental control application and your contributions help make it better for everyone. ❤️

---

## How to Contribute

1. **Fork the repository** to your own GitHub account.
2. **Clone your fork** to your local machine.
3. **Create a new branch** for your work:
   ```bash
   git checkout -b feature/your-feature-name
   ```
4. **Make your changes**. Ensure you follow the project's code style and architecture.
5. **Run tests** to ensure no regressions were introduced.
6. **Commit your changes** with clear and descriptive messages.
7. **Push to your fork**:
   ```bash
   git push origin feature/your-feature-name
   ```
8. **Create a pull request** from your fork's branch to the `main` branch of the original repository.

---

## Technical Stack

ClearNet is built using the Flutter/Dart mobile development infrastructure:

- **Language**: [Dart](https://dart.dev/)
- **Framework**: [Flutter SDK](https://flutter.dev/)
- **Data Profiles**: Asset-based embedded JSON blocks.

---

## Code Style

To keep the project consistent and maintainable:

- **Formatting**: Run `dart format .` before committing changes.
- **Linting**: Keep code analysis completely green via `flutter analyze`.
- **Focus**: Keep Pull Requests granular and dedicated to a single feature or bug fix.

---

## Testing

Please append comprehensive widget or unit tests whenever altering core filter engines.

### Run the test suite

```bash
flutter test
```

---

## Reporting Issues

If you find a bug or have a feature request, please [open an issue](https://github.com/ASPTechInc/ClearNet/issues).
