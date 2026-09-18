# Vendored SwiftMath 1.7.3 (mdv6)

Upstream: https://github.com/mgriebling/SwiftMath, tag `1.7.3`, commit `fa8244ed032f4a1ade4cb0571bf87d2f1a9fd2d7` (MIT licence, `LICENSE`).
Vendored here rather than taken as a package dependency because of the resource-bundle/codesign
conflict (D-03). Everything under `Sources/SwiftMath` is byte-identical to upstream `Sources/SwiftMath`
except the files and hunks listed below (I-011; `tools/check-swiftmath.sh` diffs against upstream, T-34).

## Patches

| # | Patch | Files / hunks |
| - | ----- | ------------- |
| 1 | **Font-bundle resolution.** `mathFonts.bundle` is located from the host app bundle first (`Contents/Resources/mathFonts.bundle`, C-13), then the SwiftPM resource bundle (probed by path — `Bundle.module` traps when absent), then the vendored source tree by `#filePath` so `swift run`/`swift test` work unbundled. | `Sources/SwiftMath/MathBundle/MathFont.swift` (`registerCGFont`, `registerMathTable`, new `enum MathFontsBundle` at end of file); `Sources/SwiftMath/MathRender/MTFont.swift` (`fontBundle`) |
| 2 | **Public `MTMathAtom.init(type:value:)`** so mdv6 can construct atoms for `MTMathAtomFactory.add(latexSymbol:value:)` (C-07.2 symbol registration). | `Sources/SwiftMath/MathRender/MTMathList.swift` (one `init`) |
| 3 | **`\boxed{…}`.** New `MTMathAtomType.boxed`, `MTBoxed` atom, `MTBoxDisplay` (frame of fraction-rule thickness with 0.35 em padding), builder support in both command paths, `mathListToString`, typesetter `makeBoxed`. | `MTMathList.swift` (`case boxed`, `typeName`, `copy()`, `class MTBoxed`); `MTMathListBuilder.swift` (two `command == "boxed"` branches, `mathListToString`); `MTTypesetter.swift` (`case .boxed`, `makeBoxed`); `MTMathListDisplay.swift` (`class MTBoxDisplay`) |
| 4 | **Trimmed font bundle.** `mathFonts.bundle` keeps only `latinmodern-math.otf`, `latinmodern-math.plist`, `GUST-FONT-LICENSE.txt`, `LICENSE`, `OFL.txt` (C-01). | `Sources/SwiftMath/mathFonts.bundle/` (deleted: the other ten fonts and their plists, `math_table_to_plist.py`) |

Not vendored: upstream `Tests/`, `img/`, `EXAMPLES.md`, `README.md`. The `Package.swift` here declares the same library target without the test target.
