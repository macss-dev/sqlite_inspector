# Troubleshooting Guide

## Gradle `metadata.bin` Error / NullPointerException

### Problem Description

When building your Android app, you may encounter the following error:

```
FAILURE: Build failed with an exception.

* What went wrong:
A problem occurred configuring project ':sqlite3_flutter_libs'.
> A build operation failed.
      Could not read workspace metadata from C:\Users\<username>\.gradle\caches\<version>\transforms\<hash>\metadata.bin
   > Could not read workspace metadata from C:\Users\<username>\.gradle\caches\<version>\transforms\<hash>\metadata.bin
> Failed to notify project evaluation listener.
   > java.lang.NullPointerException (no error message)
```

### Root Cause

This error is typically caused by a **version conflict** between your direct dependency on `sqlite3_flutter_libs` and the version required by `sqlite_inspector`.

**Example conflict scenario:**
- Your app's `pubspec.yaml` declares: `sqlite3_flutter_libs: ^0.5.33`
- `sqlite_inspector: ^0.0.3` requires: `sqlite3_flutter_libs: ^0.5.40`
- Dart's dependency resolver upgrades the version, but Gradle's transform cache becomes corrupted

---

## Solution Steps

### Step 1: Update `sqlite3_flutter_libs` Version

Edit your `pubspec.yaml` to match the version required by `sqlite_inspector`:

**Before:**
```yaml
dependencies:
  sqlite3_flutter_libs: ^0.5.33
```

**After:**
```yaml
dependencies:
  sqlite3_flutter_libs: ^0.5.40
```

### Step 2: Stop Gradle Daemons and Java Processes

**On Windows (PowerShell):**
```powershell
# Stop all Gradle daemons
cd android
.\gradlew --stop

# Stop Java processes that may be locking files
Get-Process java -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
```

**On macOS/Linux:**
```bash
# Stop all Gradle daemons
cd android
./gradlew --stop

# Stop Java processes
pkill -f gradle
```

### Step 3: Clean Gradle Cache

**On Windows:**
```powershell
# Remove the corrupted Gradle cache (adjust version number as needed)
Remove-Item -Path "$env:USERPROFILE\.gradle\caches\8.12" -Recurse -Force
```

**On macOS/Linux:**
```bash
# Remove the corrupted Gradle cache (adjust version number as needed)
rm -rf ~/.gradle/caches/8.12
```

> **Tip:** Check the error message to see which Gradle version is causing the issue.

### Step 4: Clean Flutter Project

```bash
# Return to project root
cd ..

# Clean Flutter build artifacts
flutter clean

# Get updated dependencies
flutter pub get
```

### Step 5: Clean and Rebuild Gradle

```bash
# Clean Android build
cd android
./gradlew clean  # or .\gradlew clean on Windows
cd ..
```

### Step 6: Run the Application

```bash
flutter run
```

---

## Verification

To confirm the issue is resolved:

1. ✅ `flutter pub get` completes without version conflict warnings
2. ✅ Gradle build completes successfully without metadata errors
3. ✅ Application starts normally on the device/emulator

---

## Prevention Tips

### 1. Check Dependency Requirements

Before adding a dev dependency, review its version requirements:

```bash
flutter pub deps | grep sqlite3_flutter_libs
```

### 2. Use Compatible Versions

Refer to the [version compatibility matrix](README.md#version-compatibility) in the README to ensure you're using compatible versions.

### 3. Monitor Dependency Updates

Regularly check for outdated packages:

```bash
flutter pub outdated
```

### 4. Review Version Constraints

Use `^` (caret) notation carefully. When multiple packages depend on the same library, ensure your constraint allows the highest required version:

```yaml
# ✅ Good - allows upgrades within 0.5.x
sqlite3_flutter_libs: ^0.5.40

# ❌ Problematic - locks to specific version
sqlite3_flutter_libs: 0.5.33
```

---

## Additional Resources

- [Dart Dependency Management](https://dart.dev/tools/pub/dependencies)
- [Flutter Gradle Build Issues](https://docs.flutter.dev/deployment/android#reviewing-the-gradle-build-configuration)
- [sqlite_inspector GitHub Issues](https://github.com/macss-dev/sqlite_inspector/issues)

---

## Still Having Issues?

If you're still experiencing problems after following these steps:

1. **Check your Gradle version**: Ensure you're using a compatible Gradle version (7.0+)
2. **Clear all caches**: Try removing the entire `.gradle` folder and running `flutter clean` again
3. **Update Flutter**: Ensure you're using the latest stable Flutter SDK
4. **Report an issue**: Open an issue on [GitHub](https://github.com/macss-dev/sqlite_inspector/issues) with:
   - Your Flutter version (`flutter --version`)
   - Your Gradle version (from `android/gradle/wrapper/gradle-wrapper.properties`)
   - Full error log
   - Your `pubspec.yaml` dependencies
