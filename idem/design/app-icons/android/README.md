# Idem Android app icon

This package adapts the approved Apple artwork to Android without changing its meaning or colour rhythm.

## Variants

- `source/foreground.svg`: transparent adaptive-icon foreground, internally scaled to Android's 66dp safe zone.
- `source/monochrome.svg`: single-colour silhouette for Android 13 themed icons.
- `source/legacy.svg`: white-background source for raster fallbacks and the Play Store.
- `rendered/play-store-512.png`: 512px Play Store artwork.

The adaptive background follows Yivi and remains white. Android does not select separate light and dark launcher artwork like iOS; Android 13+ uses the monochrome layer with the user's Material You colours instead.

The approved resources are installed in `android/app/src/main/res`, and the manifest uses them for both `android:icon` and `android:roundIcon`. This directory remains the editable design source.
