# PXLR

Convert an image into a 27×27 flat-color pixel mosaic. Flutter port of the
original web prototype — same crop/zoom/averaging logic, same retro-futurism
look (dark gradient background, baby-blue outlined title, chunky pixel
display font, neon-bordered panels).

## Project structure

```
lib/
  main.dart            App entry point (MaterialApp + theme)
  home_page.dart        Screen: image picking, controls, layout
  mosaic_engine.dart     Pure logic: crop/zoom/average → 27x27 Color grid, PNG export
  mosaic_painter.dart    CustomPainter: draws the grid + bold-every-9 lines
  outlined_title.dart    Reusable outlined/stroked text widget ("PXLR")
  theme.dart             Color palette + text styles
```

This archive ships **lib/ and pubspec.yaml only** — no `android/`, `ios/`,
or other platform folders. That's intentional: those folders are large,
mostly-boilerplate, and best generated fresh by the Flutter SDK on your
machine (which also stamps in the right SDK/toolchain versions for you).

## Setup

1. Unzip this into an empty folder, e.g. `pxlr/`.
2. From inside that folder, run:
   ```
   flutter create --project-name pxlr .
   ```
   This generates `android/`, `ios/`, `web/`, etc. around the existing
   `lib/` and `pubspec.yaml` — it won't overwrite them since they already
   exist (it fills in what's missing).
3. Install dependencies:
   ```
   flutter pub get
   ```
4. Run it:
   ```
   flutter run
   ```

## Permissions

`image_picker` needs a usage-description string on iOS. Add this to
`ios/Runner/Info.plist` after running `flutter create`:

```xml
<key>NSPhotoLibraryUsageDescription</key>
<string>PXLR needs access to your photos to turn one into a mosaic.</string>
```

Android's modern photo picker (used by recent `image_picker` versions on
API 33+) doesn't need a manifest permission. If you're targeting older
Android versions, you may need to add storage permissions per the
`image_picker` package's own README.

## Notes on the port

- **Sampling**: `mosaic_engine.dart` recreates the web version's approach —
  draw the (cropped/zoomed) image onto an offscreen 270×270 canvas, then
  average each 10×10 pixel block into one of the 27×27 cells.
- **Zoom**: the slider (50%–200%) crops tighter when zooming in; zooming out
  reveals a larger virtual crop square than the image has, and the area
  outside the image's real bounds is padded with a flat neutral color
  (`0xFF211F3F`) rather than distorting anything — same behavior as the web
  version's letterboxing.
- **Grid lines**: regular thin lines at every cell boundary, bolder lines
  every 9 cells, matching the web version's "ninths" grouping.
- **Export**: "Save / Share" renders the mosaic to a PNG at 30px/cell and
  opens the system share sheet (`share_plus`) rather than writing directly
  to the photo library, which keeps the permissions story simple across
  iOS and Android.
- **Font**: uses `google_fonts`' `Pixelify Sans` (display/labels) and
  `Space Mono` (body/UI text) to match the web version's typography. Fonts
  are fetched at runtime the first time they're used; for fully offline
  first-run behavior, bundle them as assets instead (see the `google_fonts`
  package docs for the asset-based setup).
