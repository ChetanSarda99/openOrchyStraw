iOS FEATURE FEASIBILITY RESEARCH — Memo App
==============================================
Generated: 2026-03-14
Context: Swift + SwiftUI, iOS 17+, @Observable, SwiftData, NavigationStack, Supabase Swift SDK

================================================================================
1. VOICE CAPTURE WITH AVFoundation
================================================================================
Complexity: MEDIUM (core recording done, transcription upload pending)

CURRENT STATE:
CaptureViewModel.swift already has AVFoundation recording wired up:
- AVAudioRecorder configured with AAC/M4A, 44.1kHz mono, high quality
- Permission handling (granted/undetermined/denied)
- Start/stop/cancel flow with timer
- Transcription currently returns a placeholder — needs backend upload

RECORDING QUALITY & FORMAT:
- Current: kAudioFormatMPEG4AAC (M4A) — correct choice
  - AAC is the best balance of quality/size for voice
  - At high quality, ~64kbps mono = ~480KB/min
  - AssemblyAI accepts M4A natively, no transcoding needed
- Alternative formats:
  - Linear PCM (WAV): Lossless but 10x file size (~5MB/min). Overkill for voice.
  - Opus: Better compression than AAC but iOS AVAudioRecorder doesn't support
    Opus directly. Would need AudioToolbox-level code.
  - FLAC: Not supported by AVAudioRecorder.
- Recommendation: KEEP M4A/AAC. It's the right call. AssemblyAI handles it.

SAMPLE RATE:
- Current: 44100 Hz — higher than needed for voice
- AssemblyAI works fine with 16kHz for speech
- Could drop to 22050 Hz to halve file size with zero perceptible quality loss
  for voice. But 44100 is not wrong — just slightly larger files.
- Recommendation: Keep 44100 for now. Only optimize if upload times become
  an issue on slow connections.

BACKGROUND RECORDING:
- Current audio session category: .playAndRecord — correct
- Background recording requires:
  1. Enable "Audio, AirPlay, and Picture in Picture" background mode in
     Xcode target capabilities
  2. Call `AVAudioSession.setCategory(.playAndRecord, mode: .default,
     options: [.defaultToSpeaker, .allowBluetooth])` — already close
  3. Recording continues when app goes to background
- iOS will show the red recording indicator in status bar
- Max recording limit (AppConstants.VoiceRecording.maxDuration = 300s) is good

WAVEFORM VISUALIZATION:
- AVAudioRecorder.isMeteringEnabled = true, then poll averagePower(forChannel:)
  every ~50ms to get amplitude data
- Display with a custom SwiftUI Shape or a horizontal bar array
- Not currently implemented — would be a nice-to-have for recording state

UPLOAD FLOW (TODO):
1. Stop recording -> get file URL
2. Upload M4A to backend (multipart/form-data or presigned S3 URL)
3. Backend sends to AssemblyAI
4. Poll or webhook for transcription result
5. Return text to app
- Recommendation: Use presigned S3 URL for upload (avoids sending audio through
  Express). Backend triggers AssemblyAI with the S3 URL.

================================================================================
2. WHEEL OF LIFE CIRCULAR CHART IN SwiftUI
================================================================================
Complexity: DONE (already implemented well)

CURRENT STATE:
WheelOfLifeChart.swift is fully implemented with:
- Custom SegmentArc Shape (radial bar segments)
- Animated fill based on note counts
- Category labels with SF Symbol icons
- Center total count
- Tap targets per segment
- Accessibility labels
- Reduce motion support
- Spring animations

CHARTS FRAMEWORK vs CUSTOM PATH:
- Swift Charts (iOS 16+) supports SectorMark for pie/donut charts
- BUT: Swift Charts does NOT support radial bar charts natively
  (where bar length varies per segment like the Wheel of Life design)
- The custom Shape/Path approach in WheelOfLifeChart.swift is correct
- Swift Charts would require hacky workarounds to get the same visual

VERDICT: Custom Path is the right approach. Already done. No changes needed.

POTENTIAL ENHANCEMENTS:
- Interactive drill-down: tap segment -> show category detail (already wired
  via onCategoryTap callback, hooked up in CategoriesView)
- Haptic feedback on segment tap
- Long-press to show tooltip with exact count
- Animatable outerRadius for smooth transitions when data changes

================================================================================
3. INFINITE SCROLL IN SwiftUI LIST
================================================================================
Complexity: LOW (already implemented, needs performance tuning)

CURRENT STATE:
SearchView.swift already has pagination:
- List with ForEach(viewModel.notes)
- Invisible Color.clear trigger when hasMore:
  `.onAppear { Task { await viewModel.loadMore() } }`
- Loading indicator at bottom
- Pull-to-refresh via .refreshable
- Page size: 20, tracked in SearchViewModel

PERFORMANCE WITH 10K+ ITEMS:
- SwiftUI List is backed by UITableView (lazy by default)
- It only creates/renders visible cells + a small buffer
- 10K items in a List is FINE — this is what UITableView was designed for
- Memory: only ~20-30 NoteRow views in memory at any time regardless of
  total count

POTENTIAL ISSUES & MITIGATIONS:
1. id stability: Note conforms to Identifiable with `let id: String` — good
2. View complexity: MemoCard is reasonably simple — no heavy image loading
3. Diffing performance: If all 10K notes are in the `notes` array, SwiftUI's
   diffing runs O(n). But since we paginate (append 20 at a time), the array
   grows incrementally — fine.
4. Memory for the Note array itself: 10K Note structs ~= 5-10MB (strings).
   Fine on modern iPhones (6GB+ RAM).

LazyVStack vs List:
- List = UITableView underneath = battle-tested scroll performance, built-in
  swipe actions, separators, .refreshable
- LazyVStack in ScrollView = more layout control but loses native List features
- Current choice (List) is correct for search results with swipe actions
- If you later need a non-list layout (e.g., masonry grid), use LazyVGrid

RECOMMENDATION:
- Current implementation is correct
- Add prefetch threshold: trigger loadMore() when user is 5 items from end
  (not at the very last item). AppConstants.Pagination.prefetchThreshold = 5
  exists but isn't used yet. Implement by checking if the appearing item's
  index is >= notes.count - 5.

IMPLEMENTATION FOR PREFETCH:
```swift
// In notesList, replace the Color.clear trigger with:
ForEach(viewModel.notes) { note in
    NoteRow(note: note)
        .onAppear {
            if note.id == viewModel.notes.suffix(5).first?.id {
                Task { await viewModel.loadMore() }
            }
        }
}
```

================================================================================
4. REAL-TIME SEARCH WITH DEBOUNCING
================================================================================
Complexity: DONE (already implemented)

CURRENT STATE:
SearchViewModel.swift uses Combine for debounce:
- PassthroughSubject<String, Never> fires on searchQuery didSet
- .debounce(for: .milliseconds(350)) — good interval for typing
- .removeDuplicates() — prevents redundant searches
- Sink dispatches to performSearch on main actor
- Local cache search runs instantly, backend search merges results

COMBINE vs ASYNC/AWAIT APPROACH:
- Combine: Current approach. Works well for reactive streams like search input.
  Debounce is a first-class operator. Clean and battle-tested.
- Async/await alternative: Would need manual Task cancellation + delay:
  ```swift
  var searchQuery = "" {
      didSet {
          searchTask?.cancel()
          searchTask = Task {
              try? await Task.sleep(for: .milliseconds(350))
              guard !Task.isCancelled else { return }
              await performSearch(query: searchQuery)
          }
      }
  }
  private var searchTask: Task<Void, Never>?
  ```
  This works but reinvents what Combine.debounce does natively.

- Recommendation: KEEP Combine for debounce. It's the right tool. The rest of
  the codebase correctly uses async/await for one-shot operations. Using Combine
  specifically for reactive input streams is the idiomatic hybrid approach.

iOS 17+ SEARCHABLE:
- Could use .searchable(text:) modifier with .onChange(of:) for automatic
  search suggestions
- Current manual MemoSearchBar + debounce gives more design control — correct
  for Memo's custom UI

================================================================================
5. MARKDOWN FILE GENERATION (Obsidian Export)
================================================================================
Complexity: MEDIUM

FILE SYSTEM ACCESS ON iOS:
- iOS is sandboxed. The app can write to its own Documents directory, temp
  directory, and shared containers.
- To export files to the user, three approaches:

  A. SHARE SHEET (UIActivityViewController / ShareLink):
     - Generate .md file in temp directory
     - Present share sheet → user can Save to Files, AirDrop, share to any app
     - SwiftUI: `ShareLink(item: fileURL)` (iOS 16+)
     - Simplest approach. User controls where it goes.
     - Can share multiple files at once.

  B. FILES APP INTEGRATION (UIDocumentPickerViewController):
     - Let user choose a directory, then write files there
     - Requires "Open In Place" document provider entitlement
     - More complex but lets user point to their Obsidian vault in iCloud
     - SwiftUI wrapper needed (UIViewControllerRepresentable)

  C. DIRECT iCLOUD DRIVE:
     - Write to iCloud Drive container programmatically
     - Requires iCloud entitlement + CloudKit or ubiquity container
     - Can write directly to Obsidian's iCloud vault folder if the user
       configures the path
     - Most seamless but most complex to set up

  D. OBSIDIAN URI SCHEME:
     - Obsidian supports `obsidian://` URLs for creating notes
     - `obsidian://new?vault=MyVault&name=NoteName&content=...`
     - Limited to one note at a time, content must be URL-encoded
     - Good for single note export, bad for bulk

RECOMMENDATION: Start with (A) ShareLink for individual/bulk export. Add (B)
UIDocumentPicker for "Export to Vault" flow where user selects their Obsidian
vault directory once, and the app remembers the security-scoped bookmark.

MARKDOWN GENERATION:
- Swift has no built-in Markdown generator (only AttributedString parsing)
- Build a simple NoteMarkdownFormatter:
  ```swift
  struct NoteMarkdownFormatter {
      static func format(_ note: Note) -> String {
          var md = "---\n"
          md += "title: \(note.displayTitle)\n"
          md += "source: \(note.source.rawValue)\n"
          md += "created: \(ISO8601DateFormatter().string(from: note.createdAt))\n"
          if let category = note.category { md += "category: \(category)\n" }
          if !note.tags.isEmpty { md += "tags: [\(note.tags.joined(separator: ", "))]\n" }
          md += "---\n\n"
          md += note.content
          return md
      }
  }
  ```
- No external library needed. String interpolation is sufficient.

================================================================================
6. OBSIDIAN VAULT STRUCTURE
================================================================================
Complexity: LOW (just file organization conventions)

OBSIDIAN COMPATIBILITY:
Obsidian reads any folder of .md files. No special format required.

VAULT STRUCTURE OPTIONS:

A. FLAT + TAGS (Obsidian's preferred way):
   ```
   vault/
   ├── Memo Imports/
   │   ├── 2026-03-14 Workout Plan.md
   │   ├── 2026-03-14 Business Idea.md
   │   └── 2026-03-13 Recipe.md
   ```
   - Tags in YAML frontmatter handle categorization
   - Obsidian's tag pane and search handle the rest
   - Simplest, most Obsidian-native approach

B. FOLDER PER CATEGORY:
   ```
   vault/
   ├── Memo/
   │   ├── Health & Fitness/
   │   │   └── Workout Plan.md
   │   ├── Career/
   │   │   └── Business Idea.md
   │   └── Quality of Life/
   │       └── Recipe.md
   ```
   - Maps Wheel of Life categories to folders
   - Works but Obsidian power users prefer tags over folders

C. DAILY NOTES STYLE:
   ```
   vault/
   ├── Memo Daily/
   │   ├── 2026-03-14.md  (all notes from that day in one file)
   │   └── 2026-03-13.md
   ```
   - Integrates with Obsidian's Daily Notes plugin
   - Good for journaling-style content

FRONTMATTER (CRITICAL):
```yaml
---
title: "Workout Plan for March"
source: telegram
category: Health & Fitness
subcategory: Exercise
tags: [gym, upper-body, dumbbells]
created: 2026-03-14T10:30:00Z
memo-id: "abc123"
---
```
- `memo-id` enables future bidirectional sync (detect already-exported notes)
- Obsidian reads YAML frontmatter natively
- Tags in frontmatter appear in Obsidian's tag pane

WIKILINKS:
- If notes reference each other, use `[[Note Title]]` syntax
- Memo could auto-link notes in the same category

RECOMMENDATION: Default to Flat + Tags (Option A). Let user choose folder
structure in export settings. Always include YAML frontmatter with memo-id.

================================================================================
7. TEMPLATE SYSTEM FOR EXPORTS
================================================================================
Complexity: MEDIUM

OPTIONS:

A. STRING INTERPOLATION (Simplest):
   - Hardcode a few template variants
   - User picks "Minimal", "Detailed", "Daily Note"
   - No user customization of template structure
   - Good enough for MVP

B. MUSTACHE-LIKE TEMPLATING:
   - Use {{ variable }} placeholders
   - Libraries: Stencil (popular Swift templating), or Mustache.swift
   - User can edit templates in a text field
   - Template example:
     ```
     # {{ title }}
     **Source:** {{ source }} | **Created:** {{ date }}
     **Category:** {{ category }}
     **Tags:** {{ tags }}

     ---

     {{ content }}

     {{ #summary }}
     ## AI Summary
     {{ summary }}
     {{ /summary }}
     ```
   - Stencil: https://github.com/stencilproject/Stencil — mature, active

C. CUSTOM TEMPLATE ENGINE:
   - Roll your own with regex replacement
   - Less flexible than Stencil but zero dependencies
   - Template: `%title%, %content%, %tags%`
   - Simple string.replacingOccurrences()

RECOMMENDATION: Start with (A) for MVP — 3 preset templates. Move to (B)
with Stencil in Phase 3 when power users request custom templates. Stencil is
lightweight (~2 files) and battle-tested in Vapor/Swift server ecosystem.

PRESET TEMPLATES FOR MVP:
1. "Minimal" — title + content only
2. "Full" — frontmatter + content + summary + tags
3. "Daily Note Append" — formatted as a section to append to a daily note

================================================================================
8. SCHEMA BUILDER UI (Dynamic Forms)
================================================================================
Complexity: HIGH

USE CASE: Users define custom note types (e.g., "Recipe" with fields:
ingredients, prep time, servings). Forms are generated from a JSON schema.

APPROACH:
- Define a NoteSchema model:
  ```swift
  struct NoteSchema: Codable, Identifiable {
      let id: String
      var name: String
      var fields: [SchemaField]
  }

  struct SchemaField: Codable, Identifiable {
      let id: String
      var label: String
      var type: FieldType
      var isRequired: Bool
      var options: [String]?  // for picker/multi-select

      enum FieldType: String, Codable {
          case text, longText, number, date, toggle, picker, multiSelect, url
      }
  }
  ```

- Dynamic form rendering:
  ```swift
  ForEach(schema.fields) { field in
      switch field.type {
      case .text: TextField(field.label, text: binding(for: field))
      case .longText: TextEditor(text: binding(for: field))
      case .number: TextField(field.label, value: numberBinding(for: field), format: .number)
      case .date: DatePicker(field.label, selection: dateBinding(for: field))
      case .toggle: Toggle(field.label, isOn: boolBinding(for: field))
      case .picker: Picker(field.label, selection: pickerBinding(for: field)) { ... }
      // etc.
      }
  }
  ```

- Data storage: Store field values as `[String: AnyCodable]` dictionary
  in the Note's metadata JSON field

CHALLENGES:
- Binding to dynamic keys requires a wrapper (dictionary-backed bindings)
- Validation per field type
- Schema editor UI (drag to reorder, add/remove fields) is significant work
- Migration when schema changes (existing notes may not have new fields)

RECOMMENDATION: Phase 2 at earliest. Start with hardcoded Wheel of Life
categories + free-form content. Schema builder is a Phase 4 power-user feature.

================================================================================
9. PARA VIEW (Projects/Areas/Resources/Archive)
================================================================================
Complexity: MEDIUM

NAVIGATION APPROACH:
- Segmented control at top of a dedicated view
- NOT separate tabs (PARA is a sub-view of Categories or a new top-level tab)

IMPLEMENTATION:
```swift
struct PARAView: View {
    @State private var selectedSegment: PARASegment = .projects

    enum PARASegment: String, CaseIterable {
        case projects, areas, resources, archive
    }

    var body: some View {
        VStack(spacing: 0) {
            Picker("View", selection: $selectedSegment) {
                ForEach(PARASegment.allCases, id: \.self) { segment in
                    Text(segment.rawValue.capitalized).tag(segment)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)

            TabView(selection: $selectedSegment) {
                // Each segment gets its own scrollable content
                ProjectsListView().tag(PARASegment.projects)
                AreasListView().tag(PARASegment.areas)
                ResourcesListView().tag(PARASegment.resources)
                ArchiveListView().tag(PARASegment.archive)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
        }
    }
}
```

- Segmented control + paged TabView = swipeable segments
- Alternative: just switch on selectedSegment without TabView animation
- PARA maps well to Wheel of Life: Areas = Wheel dimensions, Projects = active
  goals within dimensions

RECOMMENDATION: Segmented control with paged TabView. Medium effort. Depends
on backend supporting PARA classification alongside Wheel of Life categories.

================================================================================
10. RANDOM INSPIRATION (Card Flip/Swipe Animations)
================================================================================
Complexity: LOW-MEDIUM

CARD FLIP ANIMATION:
```swift
struct InspirationCard: View {
    @State private var isFlipped = false

    var body: some View {
        ZStack {
            // Front
            cardFront
                .rotation3DEffect(.degrees(isFlipped ? 180 : 0), axis: (x: 0, y: 1, z: 0))
                .opacity(isFlipped ? 0 : 1)

            // Back
            cardBack
                .rotation3DEffect(.degrees(isFlipped ? 0 : -180), axis: (x: 0, y: 1, z: 0))
                .opacity(isFlipped ? 1 : 0)
        }
        .onTapGesture {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                isFlipped.toggle()
            }
        }
    }
}
```

TINDER-STYLE SWIPE:
- Use DragGesture on cards
- Offset + rotation based on drag translation
- On release: if translation > threshold, animate off-screen + load next card
- If under threshold, spring back to center
- Stack 3 cards in a ZStack for depth effect
- Respect reduceMotion: skip animation, use button-based next/previous

RECOMMENDATION: Low effort for a single "Random Note" button that picks a
random note and shows it in a modal with a flip animation. Medium effort for
a full swipe-through deck. Build the simple version first.

================================================================================
11. FACE ID PROTECTED CATEGORIES
================================================================================
Complexity: LOW-MEDIUM

LocalAuthentication FRAMEWORK:
```swift
import LocalAuthentication

func authenticateForCategory(_ categoryId: String) async -> Bool {
    let context = LAContext()
    var error: NSError?

    guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
        // Fallback to passcode
        return await authenticateWithPasscode(context)
    }

    do {
        let success = try await context.evaluatePolicy(
            .deviceOwnerAuthenticationWithBiometrics,
            localizedReason: "Unlock protected category"
        )
        return success
    } catch {
        return false
    }
}
```

PER-CATEGORY vs APP-LEVEL:
- Per-category: More granular. Each NoteCategory gets an `isProtected: Bool`
  flag. When user navigates to a protected category, trigger Face ID.
  Store the protection flag in SwiftData (CachedCategory).
- App-level: Simpler. Lock entire app on background. Use
  .scenePhase in App entry point.
- Recommendation: PER-CATEGORY for Memo. It's the differentiating feature.
  "Mental Health" or "Emotional Life" categories are the ones users want
  private, not necessarily the whole app.

IMPLEMENTATION DETAILS:
- Store `isProtected` on CachedCategory in SwiftData
- In CategoryDetailView, check isProtected before showing notes
- Cache unlock state for current session (don't re-prompt every navigation)
- Show a lock icon on protected categories in CategoriesView
- Settings: toggle protection per category

FALLBACK: If biometrics unavailable (older device, Face ID disabled), fall
back to .deviceOwnerAuthentication (passcode). Always have a fallback.

================================================================================
12. ON-DEVICE AI WITH CORE ML
================================================================================
Complexity: HIGH (for summarization), LOW (for embeddings)

SUMMARIZATION ON-DEVICE:
- Core ML supports transformer models but with major caveats:
  - Model size: A decent summarization model (e.g., BART, T5-small) is
    200MB-1GB even quantized. App Store size limits and download time matter.
  - Performance: iPhone 15 Pro with Neural Engine can run small models
    (~100M params) in a few seconds. But quality won't match Claude 3.5.
  - Apple's Foundation Models framework (iOS 18.4+, M-series/A17+ only):
    On-device LLM via Apple Intelligence. Could be used for summarization
    if the device supports it. But: only iPhone 15 Pro+, and the API is
    limited to specific use cases Apple approves.
- VERDICT: NOT feasible for quality summarization on-device for MVP.
  Claude 3.5 Sonnet on the backend is the right approach. On-device
  summarization is a Phase 5+ optimization for offline mode.

EMBEDDINGS ON-DEVICE:
- Lightweight embedding models (MiniLM, all-MiniLM-L6-v2) are ~80MB
  and run fast on Neural Engine
- Could generate embeddings locally for offline semantic search
- NaturalLanguage framework has NLEmbedding (Apple's built-in, no model
  download needed) but quality is mediocre vs Voyage AI
- Use case: Generate embeddings on-device for local SwiftData search when
  offline, use Voyage AI embeddings for server-side search
- VERDICT: Feasible for embeddings. Consider for offline search in Phase 4.

OCR (ALREADY DECIDED):
- Apple Vision framework (VNRecognizeTextRequest) is free, on-device, and
  excellent. Already in the tech stack. No Core ML model needed.

RECOMMENDATION:
- Summarization: Keep on backend (Claude 3.5). Not worth on-device.
- Embeddings: Consider NaturalLanguage.NLEmbedding for offline search as
  a Phase 4 feature. It's free and requires no model download.
- OCR: Apple Vision. Already decided. Correct.

================================================================================
13. WIDGET SUPPORT — iOS 17 Interactive Widgets
================================================================================
Complexity: MEDIUM

iOS 17 INTERACTIVE WIDGETS:
- iOS 17 added Button and Toggle inside widgets (via App Intents)
- Perfect for Memo's "Quick Capture" concept
- WidgetKit runs in a separate process (Widget Extension target)

WIDGET IDEAS:
1. QUICK CAPTURE WIDGET (Medium size):
   - Text field-like button that opens app to Capture tab
   - "Record Voice Memo" button that starts recording via App Intent
   - Shows last captured note title

2. RANDOM INSPIRATION WIDGET (Small size):
   - Shows a random note preview
   - Tap to open in app
   - "Refresh" button (interactive) to get a new random note

3. SEARCH WIDGET (Medium/Large):
   - Recent notes list
   - Tap to open note detail
   - Button to open search

IMPLEMENTATION:
```swift
// Widget Extension target
struct MemoQuickCaptureWidget: Widget {
    let kind = "QuickCapture"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: QuickCaptureProvider()) { entry in
            QuickCaptureWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Quick Capture")
        .description("Capture ideas instantly")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// Interactive button (iOS 17+)
struct StartCaptureIntent: AppIntent {
    static var title: LocalizedStringResource = "Start Capture"

    func perform() async throws -> some IntentResult {
        // Opens app to capture tab
        return .result()
    }

    static var openAppWhenRun: Bool = true
}
```

DATA SHARING:
- Widget Extension and main app share data via App Group
- Store recent notes in shared UserDefaults or a shared SwiftData container
- App Group: `group.com.memo.app`

RECOMMENDATION: Medium effort. Do in Phase 3-4. Start with a simple
"Quick Capture" widget that opens the app. Add "Random Note" widget later.
Interactive widgets require iOS 17+ (already the minimum target — good).

================================================================================
14. REVENUCAT INTEGRATION
================================================================================
Complexity: MEDIUM

REVENUCAT + SwiftUI:
- RevenueCat SDK (purchases-ios) has first-class SwiftUI support
- PaywallView is a built-in SwiftUI component (RevenueCatUI package)
- Or build custom paywall with Offerings API

SETUP:
1. `swift package add https://github.com/RevenueCat/purchases-ios.git`
2. Configure in MemoApp.swift:
   ```swift
   import RevenueCat

   @main struct MemoApp: App {
       init() {
           Purchases.configure(withAPIKey: "rc_xxx")
       }
   }
   ```

FREE TIER ENFORCEMENT:
- Check entitlements on app launch and before premium actions:
  ```swift
  @Observable
  class SubscriptionService {
      var isPro = false
      var connectedSourceCount = 0

      func checkEntitlements() async {
          let info = try? await Purchases.shared.customerInfo()
          isPro = info?.entitlements["pro"]?.isActive == true
      }

      var canConnectNewSource: Bool {
          isPro || connectedSourceCount < 3  // Free tier: 3 sources
      }
  }
  ```

PAYWALL:
- RevenueCatUI provides a prebuilt PaywallView:
  ```swift
  PaywallView()
      .onPurchaseCompleted { transaction in
          // Handle purchase
      }
  ```
- Or build custom to match Memo's design system (recommended for brand
  consistency)
- Show paywall when user hits free tier limit (4th source connection,
  bulk export, advanced AI features)

RECOMMENDATION: RevenueCat is the standard. Use their SDK but build a custom
paywall UI using Memo's design system. Don't use their default PaywallView —
it won't match the ADHD-first design.

================================================================================
15. ONBOARDING FLOW
================================================================================
Complexity: LOW-MEDIUM

SwiftUI TABVIEW PAGING:
```swift
struct OnboardingView: View {
    @State private var currentPage = 0
    @AppStorage("hasCompletedOnboarding") private var hasCompleted = false

    var body: some View {
        TabView(selection: $currentPage) {
            OnboardingPage(
                icon: "brain.head.profile",
                title: "Your Brain's External Hard Drive",
                subtitle: "One search bar for everything you've ever saved.",
                accentColor: MemoColors.primary
            ).tag(0)

            OnboardingPage(
                icon: "link",
                title: "Connect Your Sources",
                subtitle: "Telegram, Notion, voice memos — all in one place.",
                accentColor: MemoColors.coral
            ).tag(1)

            OnboardingPage(
                icon: "magnifyingglass",
                title: "Find Anything, Instantly",
                subtitle: "AI-powered search across all your saved content.",
                accentColor: MemoColors.primaryLight
            ).tag(2)

            // Final page: Connect first source CTA
            OnboardingFinalPage {
                hasCompleted = true
            }.tag(3)
        }
        .tabViewStyle(.page(indexDisplayMode: .always))
        .indexViewStyle(.page(backgroundDisplayMode: .always))
    }
}
```

ANIMATIONS:
- Each page can have its own entrance animation using .transition()
- SF Symbol animations: `.symbolEffect(.bounce)` on page appear (iOS 17+)
- Parallax: offset background elements based on TabView scroll position
  (use GeometryReader + preference key)
- Respect reduceMotion: disable parallax/bounces

SKIP BUTTON: Top-right corner, always visible. Don't trap users in onboarding.

RECOMMENDATION: 3-4 pages max. Last page is "Connect Your First Source" CTA.
Use .tabViewStyle(.page). Add SF Symbol bounce effects (iOS 17). Simple,
quick to build. Don't over-animate.

================================================================================
16. APP STORE SCREENSHOTS
================================================================================
Complexity: LOW

APPROACHES:
1. XCODE PREVIEW + SCREENSHOT (Manual):
   - Use SwiftUI previews with sample data
   - Take screenshots from simulator (Cmd+S)
   - Edit in Figma/Sketch for device frames and marketing text

2. FASTLANE SNAPSHOT (Automated):
   - fastlane snapshot uses XCUITest to take screenshots
   - Runs on multiple simulators (iPhone 15 Pro, iPhone 15 Pro Max, etc.)
   - Automatically generates all required sizes
   - Can use fastlane frameit to add device frames + text

3. EMERGING STUDIO (Free tool by RevenueCat):
   - Web-based screenshot generator
   - Upload screenshots, add text/frames
   - Generates all required App Store sizes

4. SHOTBOT / PREVIEWED.APP:
   - Drag-and-drop screenshot designer
   - Templates for App Store aesthetics

RECOMMENDATION: Use fastlane snapshot for automated capture, then Figma for
final design polish with marketing copy. CS already uses Figma for design.
Set up snapshot after UI is stable (late Phase 2).

================================================================================
17. macOS VIA SwiftUI MULTIPLATFORM
================================================================================
Complexity: HIGH

CODE REUSE REALITY:
- Models (Note, Category, etc.): 100% reusable
- ViewModels: 90%+ reusable (business logic is platform-agnostic)
- Services (APIService, AuthService): 95% reusable (URLSession works on macOS)
- SwiftData models: 100% reusable
- Views: 40-60% reusable (Mac needs different layout paradigms)
- Design system (MemoTheme): 80% reusable (colors/typography transfer,
  spacing needs adjustment for mouse/trackpad)

WHAT NEEDS MAC-SPECIFIC UI:
1. NAVIGATION: macOS uses NavigationSplitView (sidebar + detail) not tabs
   - Sidebar with source list (Inbox, Search, Categories, Settings)
   - Detail area shows content
   - This is the biggest structural difference

2. TOOLBAR: macOS uses .toolbar with placement: .principal, .navigation
   - Search field in toolbar, not inline
   - Different button styles

3. WINDOW SIZE: Mac windows are resizable
   - Need adaptive layouts (sidebar collapses, responsive grids)
   - List items can be denser (no 44pt touch targets needed)

4. KEYBOARD SHORTCUTS: Cmd+N (new note), Cmd+F (search), etc.
   - `.keyboardShortcut("n", modifiers: .command)`

5. MENU BAR: Mac apps need proper menus
   - @CommandsBuilder in App declaration

6. CONTEXT MENUS: Right-click support (already works with .contextMenu)

7. CAPTURE: No voice recording paradigm on Mac (different input model)
   - Text capture is primary on Mac
   - Could support mic recording but UI is different

REALISTIC TIMELINE:
- If iOS app is complete: 4-6 weeks for a solid macOS port
- Most time spent on NavigationSplitView conversion and Mac-specific chrome
- Use `#if os(macOS)` / `#if os(iOS)` for platform-specific code

RECOMMENDATION: Wait until iOS is polished (end of Phase 2). Then add macOS
as a Multiplatform target. The shared model/viewmodel/service layer will
save significant time. Budget 4-6 weeks dedicated effort.

================================================================================
18. WEB APP (Next.js)
================================================================================
Complexity: HIGH (separate frontend codebase)

BACKEND SHARING:
- YES — the existing Express backend serves REST JSON
- Next.js frontend would call the same /notes, /search, /sources endpoints
- Authentication: Same Supabase Auth — Supabase has a JS SDK
- No backend changes needed (it's already API-first)

FRONTEND-SPECIFIC WORK:
1. Full Next.js app scaffolding (App Router, TypeScript)
2. Auth flow (Supabase JS client for login/signup)
3. All UI components rebuilt (React, not SwiftUI)
4. Search page, note detail, categories, settings
5. Responsive design (mobile web + desktop)
6. Real-time updates (WebSocket or polling)
7. Voice capture (Web Audio API for recording, same backend for transcription)
8. File upload for voice memos
9. SEO/marketing pages

SHARED TYPES:
- Could share TypeScript interfaces between backend and frontend
  via a shared package or monorepo
- Backend's `models/types.ts` already defines Note, ConnectedSource, etc.

ESTIMATED EFFORT: 8-12 weeks for a full web app with feature parity.
The backend is 100% reusable. The frontend is 100% new code.

RECOMMENDATION: Web app is a Phase 5+ initiative. iOS + macOS first.
If web access is needed sooner, consider a lightweight "search-only" web
interface (one page, search bar, results) — could be done in 1-2 weeks.

================================================================================
iOS 17/18 APIs MEMO SHOULD LEVERAGE
================================================================================

--- APP INTENTS (Siri Shortcuts) ---
Complexity: MEDIUM
iOS 17+: App Intents framework replaces SiriKit Intents
- "Hey Siri, capture a note in Memo"
- "Hey Siri, search Memo for workout ideas"
- Appear in Shortcuts app for automation
Implementation:
```swift
struct CaptureNoteIntent: AppIntent {
    static var title: LocalizedStringResource = "Capture Note"

    @Parameter(title: "Content")
    var content: String

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let body = CreateNoteBody(content: content, title: nil, source: .manual, category: nil, tags: nil)
        let note = try await APIService.shared.createNote(body)
        return .result(dialog: "Saved: \(note.displayTitle)")
    }
}
```
RECOMMENDATION: Add after core features are stable. Medium effort. High value
for ADHD users (voice-activated capture without opening the app).

--- SHARE EXTENSION ---
Complexity: MEDIUM
- User shares from ANY app -> Memo captures it
- Requires a Share Extension target (separate process)
- Receives URL, text, images via NSExtensionContext
- Writes to shared App Group container or calls API directly
- Essential for the "save from anywhere" value proposition
RECOMMENDATION: Phase 2 priority. This is a core differentiator. Without it,
users must manually open Memo to capture content from other apps.

--- SPOTLIGHT INTEGRATION (Core Spotlight) ---
Complexity: LOW
- Index notes in Spotlight so users can find Memo content from Home Screen search
- CSSearchableItem for each note
Implementation:
```swift
import CoreSpotlight

func indexNote(_ note: Note) {
    let attributes = CSSearchableItemAttributeSet(contentType: .text)
    attributes.title = note.displayTitle
    attributes.contentDescription = note.contentPreview
    attributes.keywords = note.tags

    let item = CSSearchableItem(
        uniqueIdentifier: note.id,
        domainIdentifier: "com.memo.notes",
        attributeSet: attributes
    )

    CSSearchableIndex.default().indexSearchableItems([item])
}
```
- When user taps Spotlight result, app opens to that note
- Handle via `onContinueUserActivity(CSSearchableItemActionType)`
RECOMMENDATION: Low effort, high value. Add in Phase 2. Makes Memo content
discoverable outside the app.

--- BACKGROUND TASKS (BGTaskScheduler) ---
Complexity: MEDIUM
- Schedule periodic sync in background
- Two types:
  A. BGAppRefreshTask: ~30 seconds of runtime, runs periodically
  B. BGProcessingTask: Minutes of runtime, runs during charging/wifi
- Use for:
  - Syncing Telegram/Notion in background
  - Generating embeddings for new notes
  - Updating cached categories
Implementation:
```swift
// Register in MemoApp.init()
BGTaskScheduler.shared.register(
    forTaskWithIdentifier: "com.memo.sync",
    using: nil
) { task in
    handleSync(task: task as! BGAppRefreshTask)
}

// Schedule
func scheduleSync() {
    let request = BGAppRefreshTaskRequest(identifier: "com.memo.sync")
    request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60)
    try? BGTaskScheduler.shared.submit(request)
}
```
RECOMMENDATION: Phase 2-3. Critical for the "always up to date" promise.
Without background sync, users must open the app to trigger syncs.

--- TRANSFERABLE (Drag & Drop, Copy/Paste) ---
Complexity: LOW
- iOS 16+ protocol for rich copy/paste and drag-and-drop
- Make Note conform to Transferable:
```swift
extension Note: Transferable {
    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .json)
        ProxyRepresentation(exporting: \.content) // plain text fallback
    }
}
```
- Enables: drag a note from Memo to another app, copy note as text
RECOMMENDATION: Low effort. Add when Notes list is stable.

--- TIPKIT (iOS 17+) ---
Complexity: LOW
- Contextual tips/hints for features
- "Swipe left to delete, swipe right to favorite"
- "Try searching with natural language"
- Perfect for ADHD onboarding: gentle, contextual, not overwhelming
RECOMMENDATION: Add during Phase 2 polish. Very low effort.

--- OBSERVATION FRAMEWORK (iOS 17+) ---
Already using. @Observable macro throughout ViewModels. Correct.

--- SwiftData (iOS 17+) ---
Already using for CachedNote, CachedCategory. Correct.

================================================================================
SUMMARY MATRIX
================================================================================

Feature                    | Complexity | Phase    | Status
---------------------------|------------|----------|--------
1. Voice Capture           | MEDIUM     | M1.5     | Core done, upload TODO
2. Wheel of Life Chart     | DONE       | M1.5     | Fully implemented
3. Infinite Scroll         | LOW        | M1.5     | Done, add prefetch
4. Search Debounce         | DONE       | M1.5     | Fully implemented
5. Markdown Generation     | MEDIUM     | M1.9     | Not started
6. Obsidian Vault          | LOW        | M1.9     | Convention decisions only
7. Template System         | MEDIUM     | M1.9     | 3 presets for MVP
8. Schema Builder UI       | HIGH       | Phase 4  | Defer
9. PARA View               | MEDIUM     | Phase 2  | Segmented + TabView
10. Random Inspiration     | LOW-MED    | Phase 2  | Card flip + optional swipe
11. Face ID Categories     | LOW-MED    | Phase 4  | LAContext, per-category
12. On-Device AI           | HIGH/LOW   | Phase 4+ | No summarization, maybe embeddings
13. Widget Support         | MEDIUM     | Phase 3  | Quick Capture widget first
14. RevenueCat             | MEDIUM     | Phase 5  | Custom paywall, not default UI
15. Onboarding             | LOW-MED    | Phase 5  | TabView paging, 3-4 pages
16. App Store Screenshots  | LOW        | Phase 5  | fastlane + Figma
17. macOS Multiplatform    | HIGH       | Phase 6  | 40-60% view reuse
18. Web App (Next.js)      | HIGH       | Phase 6+ | Backend 100% shared

iOS APIs to add:
- Spotlight (LOW, Phase 2)         — search notes from Home Screen
- Share Extension (MEDIUM, Phase 2) — capture from any app
- App Intents/Siri (MEDIUM, Phase 3) — voice-activated capture
- Background Tasks (MEDIUM, Phase 2) — auto-sync sources
- TipKit (LOW, Phase 2)           — contextual feature hints
- Transferable (LOW, Phase 2)     — drag/drop notes

HIGHEST IMPACT, LOWEST EFFORT (do these next):
1. Spotlight indexing — makes Memo content findable from anywhere
2. Share Extension — "save from any app" is the core promise
3. Background sync — keeps content fresh without user action
4. Prefetch threshold in infinite scroll — already have the constant defined
