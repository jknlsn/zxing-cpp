# Swift Wrapper

This wrapper supports two build/link modes through the root SwiftPM manifest at [Package.swift](../../Package.swift).

## Build Modes

### 1) Bundled source build (default)

Builds zxing-cpp core from source as part of the package.
No preinstalled `libZXing` is required.

```bash
swift build
```

Equivalent explicit form:

```bash
ZXING_BUNDLED=1 swift build
```

### 2) External native library

Links against an already available native `ZXing` library.
Use this when you provide `libZXing` via your own build/distribution system (e.g. homebrew).

```bash
ZXING_BUNDLED=0 swift build -Xcc `pkgconf --cflags zxing` -Xlinker `pkgconf --libs-only-L zxing`
```

## Demo Targets

From repository root:

```bash
swift run demo_writer "Hello World" QRCode out.png
swift run demo_reader out.png
```

For external mode demos, prefix commands with `ZXING_BUNDLED=0` and pass linker paths as needed.

```bash
ZXING_BUNDLED=0 swift run -Xcc `pkgconf --cflags zxing` -Xlinker `pkgconf --libs-only-L zxing` demo_writer "Hello World" QRCode out.png

ZXING_BUNDLED=0 swift run -Xcc `pkgconf --cflags zxing` -Xlinker `pkgconf --libs-only-L zxing` demo_reader out.png
```

## API Notes

### ImageView transforms are immutable

`ImageView` is a non-owning view over caller-managed pixel data. Transform operations return a
new view object that reuses the same underlying pixel buffer (zero-copy), instead of mutating the
existing one in place.

```swift
let image = try ImageView(data: data, width: width, height: height, format: .lum)
let cropped = try image.cropped(left: 10, top: 10, width: 200, height: 100)
let rotated = try cropped.rotated(by: 90)

let barcodes = try BarcodeReader().read(from: rotated)
```

### UIImage decoding normalizes orientation

On iOS, `BarcodeReader.read(from: UIImage)` renders the image into an upright `CGImage` before
decoding. This means the convenience API respects `UIImage.imageOrientation` and also works for
CI-backed `UIImage` values that do not expose a direct `cgImage`.

### Barcode is a value type

`Barcode` snapshots all public fields into immutable Swift data, so equality and hashing are based
on barcode contents rather than native pointer identity. The type is also `Sendable`, making it
safe to pass decoded results across Swift concurrency domains.

### Barcode creation has typed Swift option structs

Prefer `BarcodeCreationOptions` for format-specific creation settings. The wrapper exposes typed
Swift structs for QR variants, Data Matrix, PDF417, Aztec, MaxiCode, and Code 128, then serializes
them to the native JSON-based creator API.

```swift
let barcode = try Barcode(
    "Hello World",
    options: .qrCode(
        QRCodeOptions(
            errorCorrection: .high,
            version: 7,
            dataMask: .pattern3
        )
    )
)

let svg = try barcode.toSVG()

let pdf417 = try Barcode(
    "Hello PDF417",
    options: .pdf417(
        PDF417Options(
            errorCorrectionLevel: .level4,
            columns: 4,
            rows: 12
        )
    )
)
```

`CreatorOptions` and the raw string initializer remain available as escape hatches for native
options that do not yet have dedicated Swift surface area.

Boolean creator keys currently exposed through the Swift wrapper (`gs1`, `readerInit`, and
`forceSquare`) behave as presence flags when serialized for the native creator bridge. `true`
emits the key; `false` is omitted rather than encoded explicitly. This matches the current native
creator semantics and avoids changing behavior for other wrappers sharing the same bridge.

```swift
let barcode = try Barcode(
    "Hello World",
    format: .qrCode,
    options: CreatorOptions(ecLevel: "H", version: 7)
)

let raw = try Barcode(
    "Hello World",
    options: .rawString(format: .qrCode, payload: #"{"EcLevel":"H"}"#)
)
```
