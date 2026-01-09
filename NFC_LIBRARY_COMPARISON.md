# NFC Library Comparison for MRTD Reading: nfc_manager vs flutter_nfc_kit

## Executive Summary

**Recommendation: Stay with flutter_nfc_kit BUT requires modification**

Neither library currently solves the Android PACE authentication issue out-of-the-box. Both require custom modifications to expose `EXTRA_READER_PRESENCE_CHECK_DELAY`.

---

## Library Comparison

### flutter_nfc_kit

**Version:** 3.6.1 (published 27 days ago)
**Publisher:** nfc.im (verified)
**Downloads:** 36.1k weekly
**Popularity:** 264 likes, 160 pub points
**Repository:** https://github.com/nfcim/flutter_nfc_kit
**Stars:** Not found in search
**License:** MIT

#### Pros
✅ **Industry standard for MRTD reading** - dmrtd library depends on it
✅ Recently maintained (published 27 days ago)
✅ Web support via WebUSB protocol
✅ vcmrtd already uses it (no migration needed)
✅ Event streaming mode for continuous scanning
✅ Verified publisher

#### Cons
❌ **Does NOT expose EXTRA_READER_PRESENCE_CHECK_DELAY**
❌ Limited Android reader mode configuration
❌ Uses `null` for Bundle options in `enableReaderMode()`
❌ Critical iOS CoreNFC bug on iOS 14.5 and earlier
❌ RC (Release Candidate) version in use (3.6.0-rc.6)

#### Android Implementation
```kotlin
nfcAdapter.enableReaderMode(activity.get(), pollHandler, technologies, null)
//                                                                      ^^^^ No Bundle options!
```

---

### nfc_manager

**Version:** 4.1.1
**Publisher:** okadan.net (verified)
**Downloads:** 57.9k weekly
**Popularity:** 512 likes, 160 pub points
**Repository:** https://github.com/okadan/flutter-nfc-manager
**Stars:** 242
**Forks:** 200
**Contributors:** 7
**License:** MIT

#### Pros
✅ **More popular** (512 likes vs 264, 57.9k vs 36.1k weekly downloads)
✅ Stable release (not RC)
✅ Larger community (242 stars, 200 forks)
✅ Modular architecture (separate packages for NDEF, FeliCa)
✅ Better documented API

#### Cons
❌ **Does NOT expose EXTRA_READER_PRESENCE_CHECK_DELAY** ([Issue #86](https://github.com/okadan/flutter-nfc-manager/issues/86) open since 2022)
❌ **No MRTD-specific support** - no passport reading examples
❌ **Not used by dmrtd** - the established MRTD library
❌ 120 open issues (maintenance concerns)
❌ Only 7 contributors
❌ No native MRTD implementations found

---

## The Critical Issue: EXTRA_READER_PRESENCE_CHECK_DELAY

### What is it?
Android NFC parameter that controls how frequently the OS checks if the NFC tag is still present.

- **Default:** 125ms
- **Required for PACE:** 1000ms minimum (some implementations use 120,000ms!)

### Why it matters for PACE
PACE authentication involves cryptographic operations that take 4-6 seconds. During this time:
1. Card is busy computing (key generation, nonce encryption)
2. Android OS performs presence checks every 125ms by default
3. On Broadcom NFC controllers, these checks **interfere with the transaction**
4. Card returns `6800` error or transaction fails

### The Problem
**NEITHER library exposes this parameter!**

Both pass `null` for Bundle options when calling `enableReaderMode()`, meaning they use system defaults.

### Evidence
From [GitHub issue #86 (nfc_manager)](https://github.com/okadan/flutter-nfc-manager/issues/86):
> User reported that setting `EXTRA_READER_PRESENCE_CHECK_DELAY` to **120000ms** successfully resolved transceive failures

From [Android 13+ fix](https://github.com/Governikus/AusweisApp/pull/52):
> "Unless the EXTRA_READER_PRESENCE_CHECK_DELAY is set to something high like 1000 ms, the smartcard will be considered lost by AOSP NfcNci implementation"

---

## MRTD Support Analysis

### flutter_nfc_kit for MRTD
- ✅ **dmrtd library** (ZeroPass) depends on flutter_nfc_kit
- ✅ vcmrtd (this project) already uses it
- ✅ Established as MRTD reading standard in Flutter
- ✅ Used in production MRTD apps

### nfc_manager for MRTD
- ❌ No MRTD-specific examples or documentation
- ❌ Not used by major MRTD libraries
- ❌ No passport/ID card reading implementations found
- ⚠️ Would require rewriting all NFC communication layer

---

## Platform Support Comparison

| Feature | flutter_nfc_kit | nfc_manager |
|---------|----------------|-------------|
| Android IsoDep | ✅ Yes | ✅ Yes (IsoDepAndroid) |
| iOS ISO7816 | ✅ Yes | ✅ Yes (Iso7816Ios) |
| Web Support | ✅ WebUSB | ❌ No |
| NDEF | ✅ Yes | ✅ Yes (via nfc_manager_ndef) |
| Reader Mode Config | ❌ Limited | ❌ Limited |
| Presence Check Delay | ❌ No | ❌ No ([Issue #86](https://github.com/okadan/flutter-nfc-manager/issues/86)) |

---

## Dutch Driver License Support

Both libraries support ISO 14443 Type A/B which is used by:
- ✅ **Passports** (ICAO 9303)
- ✅ **ID Cards** (ISO 14443-4)
- ✅ **Dutch Driver Licenses** (ISO 14443-4 compliant)

**However**, the critical issue for ALL these documents is PACE authentication support, which requires `EXTRA_READER_PRESENCE_CHECK_DELAY`.

---

## Maturity Assessment

### flutter_nfc_kit
- **Age:** ~5+ years (based on version 3.6.1)
- **Maintenance:** Active (published 27 days ago)
- **Stability:** Using RC version (3.6.0-rc.6) suggests ongoing development
- **MRTD Track Record:** Proven with dmrtd integration
- **Grade:** B+ (mature but using RC version)

### nfc_manager
- **Age:** Since September 2019 (6+ years)
- **Maintenance:** Moderate (141 commits, but 120 open issues)
- **Stability:** Stable releases
- **MRTD Track Record:** None found
- **Grade:** B (mature but no MRTD focus)

---

## Solutions for the PACE Issue

### Option 1: Fork flutter_nfc_kit (Recommended)
**Effort:** Low-Medium
**Impact:** High
**Maintainability:** Medium

Modify `FlutterNfcKitPlugin.kt`:
```kotlin
// Current code
nfcAdapter.enableReaderMode(activity.get(), pollHandler, technologies, null)

// Modified code
val options = Bundle()
options.putInt(NfcAdapter.EXTRA_READER_PRESENCE_CHECK_DELAY, 1000)
nfcAdapter.enableReaderMode(activity.get(), pollHandler, technologies, options)
```

Expose as parameter in Dart API:
```dart
await FlutterNfcKit.poll(
  timeout: Duration(seconds: 10),
  iosAlertMessage: "Hold your iPhone near the passport",
  presenceCheckDelay: 1000, // New parameter
);
```

### Option 2: Create Platform Channel
**Effort:** Medium
**Impact:** High
**Maintainability:** Low (duplicates NFC code)

Create custom Android method channel to handle NFC with proper Bundle options.

### Option 3: System-wide Fix (Android Only)
**Effort:** Low (for users)
**Impact:** High
**Maintainability:** N/A (user responsibility)

Use [NfcNci_Patience](https://github.com/StarGate01/NFCPresenceFix) Xposed module:
- Modifies AOSP NfcNci at system level
- Sets 1000ms delay for all apps
- Requires rooted device or custom ROM

### Option 4: Switch to nfc_manager + Fork
**Effort:** Very High (complete rewrite)
**Impact:** Medium (same issue exists)
**Maintainability:** Low

Not recommended - requires:
- Complete NFC layer rewrite
- Same Bundle modification needed
- No MRTD-specific benefits
- Loss of dmrtd compatibility

---

## Recommendation

### ✅ Stay with flutter_nfc_kit + Fork/Modify

**Reasoning:**
1. Already integrated with vcmrtd
2. Industry standard for MRTD (dmrtd uses it)
3. Recent maintenance activity
4. Web support for future use
5. Switching to nfc_manager provides **no advantage** for this issue

**Action Items:**
1. Fork flutter_nfc_kit
2. Add `EXTRA_READER_PRESENCE_CHECK_DELAY` parameter (hardcoded 1000ms or configurable)
3. Test with Motorola Moto G7
4. Submit PR to upstream flutter_nfc_kit
5. Document workaround for other users

---

## References

1. [flutter_nfc_kit Issue #86 - EXTRA_READER_PRESENCE_CHECK_DELAY](https://github.com/okadan/flutter-nfc-manager/issues/86)
2. [Android 13+ NFC Presence Timeout Fix](https://github.com/Governikus/AusweisApp/pull/52)
3. [NfcNci_Patience Xposed Module](https://github.com/StarGate01/NFCPresenceFix)
4. [dmrtd - Dart MRTD Library](https://github.com/ZeroPass/dmrtd)
5. [Android NfcAdapter.EXTRA_READER_PRESENCE_CHECK_DELAY](https://developer.android.com/reference/android/nfc/NfcAdapter#EXTRA_READER_PRESENCE_CHECK_DELAY)

---

## Conclusion

**nfc_manager is NOT a better alternative** for MRTD/passport/ID card/Dutch driver license reading because:

❌ No MRTD-specific support or examples
❌ Same `EXTRA_READER_PRESENCE_CHECK_DELAY` issue as flutter_nfc_kit
❌ Would require complete codebase rewrite
❌ Not used by established MRTD libraries
❌ No advantages for solving the current PACE issue

**The solution is to modify flutter_nfc_kit**, not switch libraries. The issue is not library choice but a missing Android NFC configuration that affects both libraries equally.
