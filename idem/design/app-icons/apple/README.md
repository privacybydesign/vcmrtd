# Idem Apple app icon

`Idem.icon` is an Apple Icon Composer source package based on the approved Idem colour-rhythm mark. It follows the current Yivi (`irmamobile`) setup: a white automatic-gradient background in the light appearance, an automatic system background in the dark appearance, and appearance-specific vector artwork.

## Artwork

- Light: `#E02146`, `#BA3353`, `#6A2E4A`, and `#97C6DD`.
- Dark: `#FF0943`, `#E02146`, `#D30A39`, and `#6FA6C4`.
- The dark mapping comes from Yivi's square Icon Composer specialization (`new-logo-dart7.svg`). The credential blue is lifted to Yivi's `#6FA6C4` dark-icon blue for legibility.
- The person remains split between the document and live-camera colours. Blue is reserved for the credential data lines, giving it a concrete role without dividing the person.
- Both SVGs are transparent foreground artwork. Icon Composer provides the background and final platform mask; do not bake rounded corners into production exports.

## Files

- `Idem.icon/`: editable Icon Composer package with light and dark appearances.

The approved package is installed at `ios/Runner/Idem.icon` and selected as the app icon for the Debug, Release, and Profile configurations. This directory remains the editable design source.
