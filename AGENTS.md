# Repository Guidelines

## Project Structure & Module Organization
Source for the SwiftUI app lives under `PDFTools/`. `PDFToolsApp.swift` initializes the shared `AppState` when the scene tree boots. Views stay in `Views/`, with stateful logic in `ViewModels/` and feature services in `Services/` (e.g., `PDFProcessor.swift`, `ImageProcessor.swift`). Domain models belong in `Models/`, while cross-cutting helpers (sizes, URL utilities) go in `Utilities/`. Store icons and localized assets in `Assets.xcassets`, and mirror this layout inside Xcode groups when adding files.

## Build, Test, and Development Commands
Use Xcode for day-to-day work: `open PDFTools.xcodeproj` launches the project with the `PDFTools` scheme. For CI or local automation, run `xcodebuild -scheme PDFTools -destination 'platform=iOS Simulator,name=iPhone 15' build` to ensure the app compiles. Once a test target exists, prefer `xcodebuild test -scheme PDFTools -destination 'platform=iOS Simulator,name=iPhone 15'` to exercise the suite.

## Coding Style & Naming Conventions
Follow standard Swift style: four-space indentation, 120-character line width, and Swift API naming (camelCase for members, PascalCase for types). Suffix SwiftUI state containers with `ViewModel`, service classes with `Processor`, and errors with `Error`. Favor async/await flows, matching `PDFProcessor.compressPDFWithFilter`. Run `swiftformat .` if you introduce the formatter; otherwise match the committed style before pushing.

## Testing Guidelines
Add XCTest cases under `PDFToolsTests/`, mirroring the source layout (e.g., `Services/PDFProcessorTests.swift`). Name test methods `test_<condition>_<expected>()` and cover both the success path and the error branches around sandboxed file access. Target coverage across compression, scaling, and image-processing flows. Execute tests via Xcode or `xcodebuild test -scheme PDFTools -destination 'platform=iOS Simulator,name=iPhone 15'` before raising a pull request.

## Commit & Pull Request Guidelines
Write commits in imperative mood (`Add image resizing alert`, `Refactor view model state`), keep subject lines ≤72 characters, and add a body when extra context helps reviewers. Pull requests should describe the change, link issues, attach UI screenshots for visual tweaks, and mention new commands or dependencies. Request review only after CI passes and feedback is addressed.

## Security & Configuration Tips
Respect security-scoped URLs: copy inbound files to a temporary location first, as `AppState.handleIncomingURL` demonstrates. Update entitlements and `Info.plist` when enabling new document types or share extensions, and document new permissions or sandbox requirements in the pull request summary.
