# AdaptiveTouch

AdaptiveTouch is an experimental, native iPhone healthcare-navigation demonstration for people who may find precise touch or holding a phone steady difficult. It uses fictional data, works without an account or network, and stores settings and demo bookings locally. It does not diagnose or treat a condition, connect to healthcare providers, or change the interface or touch behavior of other apps.

## Current status

The repository contains a SwiftUI application, an Xcode project, a Core Motion pipeline, UIKit touch controls, a local appointment workflow, setup screens, an interaction exercise and XCTest sources. **The app has not yet been built with the iOS SDK or tested on an iPhone.** The development Mac had Apple command-line tools and Swift 6.3.2 but no full Xcode or iOS SDK. Swift syntax parsing, project/scheme structure checks, and macOS type-checks of the platform-independent motion and touch algorithms succeeded. The iOS target and XCTest suite remain unverified; installation and physical usability cannot be guaranteed until they are built and tested in Xcode.

## Requirements and project setup

- macOS with a current Xcode installation containing the iOS SDK; iOS 16 or later on an iPhone.
- An Apple ID/development team for signing on a physical device. Xcode's signing capabilities depend on your account.
- IntelliJ IDEA and Codex may be used to edit this folder; Xcode supplies the native iOS build, simulator, signing and device tools.
- No third-party libraries, account, network connection, Apple Watch or external sensor is required by the app.

Open `AdaptiveTouch.xcodeproj` in Xcode and select the shared **AdaptiveTouch** scheme. In the app target's **Signing & Capabilities**, choose your team and replace `org.example.AdaptiveTouch` with a unique bundle identifier. Xcode may require a corresponding unique identifier for the test target. Select a simulator for an initial build, or connect an iPhone and select it as the run destination. Trust the computer and enable Developer Mode if the device requests them. Build and run with Command-R. If signing fails, check the selected team, unique bundle identifier, device trust and account provisioning in Xcode; the repository cannot supply your signing identity.

Command-line examples after installing and selecting Xcode:

```sh
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
xcodebuild -list -project AdaptiveTouch.xcodeproj
xcodebuild -project AdaptiveTouch.xcodeproj -scheme AdaptiveTouch -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build
xcodebuild -project AdaptiveTouch.xcodeproj -scheme AdaptiveTouch -destination 'platform=iOS Simulator,name=iPhone 16' test
```

Choose a simulator name that actually exists in `xcrun simctl list devices available`. For a physical device, configure signing in Xcode and use its Run button; a simulator does not reproduce physical motion or hand interactions. When adding Swift files, run `python3 scripts/generate_project.py` to update the generated project references; this regenerates the project and shared scheme, so keep project-specific edits in the generator.

## Using the app

The welcome screen links to the healthcare dashboard, calibration and accessibility settings. The dashboard offers appointments, scheduling, fictional medications and information. Scheduling chooses a specialty, fictional doctor, date and time; a separate review screen requires explicit confirmation. Duplicate bookings for the same doctor and time are rejected. Demo appointments can be removed after confirmation and restored using Undo. Data remains on this device.

In **Accessibility Settings**, adjust stabilization, strength, maximum offset, motion sensitivity, outer margin, target expansion, finger movement tolerance, protection mode, hold duration and feedback. **Recenter** updates the neutral attitude. System Dynamic Type and accessibility contrast settings are used by the platform; Reduce Motion can also be enabled in the app. Motion updates stop when the app is backgrounded or stabilization is disabled. Sensor diagnostics show live readings when available. Simulation is developer-controlled, clearly labeled, and should be turned off when evaluating actual phone motion.

Calibration samples natural motion and a deliberate tilt for three seconds each, then offers practice taps and a sensitivity suggestion calculated from average angular rate. It does not yet measure touch accuracy, estimate an individual tremor frequency, or use the deliberate sample to tune the classifier. Touch expansion and tolerance recommendations are conservative defaults. It is optional, requires the motion sensor enabled, and rejects simulated samples. Tap **Apply Settings** to save the suggested sensitivity and recenter.

**Test AdaptiveTouch** provides standard and assisted runs with the same target sequence. It reports successes, incorrect target selections, taps on empty grid cells, mean and median selection time, and elapsed time from actual interactions. The screen defines those metrics and their limits: it cannot measure touches outside the grid or canceled attempts. Corrected near misses and ambiguous contacts are not yet reported, and the two presentations differ visually. Results are demonstration data, not an effectiveness study.

## Design and algorithms

- `App` owns scene lifecycle, persisted settings, the safe-area-aware dark margin container and the motion/touch connection. The translated container includes both its visuals and UIKit controls, so hit testing follows the view transform. Insets and offsets use points and clamp to available margins. Device verification of visual and touch alignment is essential.
- `Motion` obtains `CMDeviceMotion` at a requested 50 Hz on a serial background queue. Samples contain timestamp, rotation rate, attitude, gravity and user acceleration; no acceleration is integrated to estimate displacement. A bounded 0.8-second window examines angular-rate magnitude and sign reversals. High rates/acceleration signal sudden motion, sustained directional motion signals deliberate movement, repeated moderate reversals signal tremor-like motion, low rates signal stillness and other patterns are uncertain. Four consecutive classifications provide hysteresis, while sudden motion stops compensation immediately. This is a heuristic, not a diagnosis.
- The stabilizer maps short-term roll and pitch deviations in radians to portrait screen points, with bounded gain, slow reference adaptation, smoothing and zero target outside tremor-like states. It can freeze its current offset while a custom control is pressed. Sensor axes and signs are provisional; phone translation cannot be recovered reliably by integrating acceleration, and the result is not world-locked. Recenter changes the reference on the next sample.
- `Touch` provides geometry conversion, a deterministic nearest-target resolver, intent tracking and duplicate-action protection. Portal controls use a UIKit control whose invisible padding occupies its own layout space, avoiding overlap with adjacent controls. It anchors the initial control, allows small movements, cancels directional gestures and cooperates with native scrolling; accessibility activation uses UIKit's supported accessibility path. High-risk confirmation requires a visible hit. Native system controls retain their normal behavior. The standalone resolver's ambiguity and near-miss logic is tested separately; it is not a global registry and is not used to resolve touches between portal controls.
- `Screens` and `Models` provide the fictional workflow, settings, setup and exercise. `AdaptiveTouchTests` contains unit tests for motion, geometry, touch intent, duplicate protection and local booking behavior.

Touch modes are normal, protected (rejects very brief contacts), and optional hold-to-activate. Duplicate protection is per control, while booking also checks persisted records. Neither pressure nor a cursor is used. Custom controls are limited to this app; native text input and system gestures are not globally intercepted.

## Physical-device evaluation

1. Install and launch as described above. Open Accessibility Settings → Sensor diagnostics and verify that the sensor is available and rotation values change when the phone moves. Simulation must be off.
2. Recenter in a comfortable grip, then try stillness, gentle oscillation, a deliberate tilt, a sudden reposition and grip changes. Check that the interface remains within the dark margins and does not worsen usability. Disable stabilization if it does.
3. Tap visible and padded areas while the screen moves; verify that the intended visible control activates. Try small movements during a press, a deliberate scroll, a second finger, interruptions, VoiceOver, large text, Reduce Motion, and the home gesture. Try protected and hold modes separately.
4. Complete a fictional booking twice and verify review, duplicate prevention, removal confirmation and Undo. Run both comparison exercises; do not treat their output as clinical evidence.
5. Inspect Xcode's debug console and use Instruments for performance and battery measurement. None of these physical checks has yet been performed for this repository.

## Known gaps and next steps

This is an unverified prototype, not a completed or validated assistive product. The iOS build, UI tests, accessibility audit, sensor axis mapping, touch alignment, scroll behavior, multi-touch across separate controls and performance need testing on real devices. A global target registry, overlap arbitration in the live UI, automatic hitbox adaptation, complete touch calibration, full comparison metrics, touch diagnostics, explicit text-scaling controls and UI automation are not implemented. The simulation and accessibility options should be evaluated with users before relying on them. First install Xcode, run the build and XCTest suite, fix any SDK/compiler issues revealed, then perform the physical checks above.
