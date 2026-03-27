# Figma MCP Setup Guide for Memo

## What is Figma MCP?

**Figma MCP (Model Context Protocol)** connects Figma designs directly to Claude Code, allowing you to:
- Turn Figma designs into production code
- Extract design tokens (colors, spacing, typography)
- Keep code synced with design updates
- Generate code that matches your actual components

**Why this matters for Memo:**
- Design the app visually in Figma FIRST
- Convert screens to SwiftUI/React code automatically
- Maintain design system consistency
- Ship faster with AI-assisted implementation

---

## Prerequisites

- ✅ Figma account (Free or paid)
- ✅ Claude Code installed globally
- ✅ Figma desktop app (required for MCP server)

---

## Setup (5 minutes)

### Option 1: Recommended - Figma Plugin (Easiest)

**1. Install Figma plugin for Claude Code:**
```bash
claude plugin install figma@claude-plugins-official
```

This automatically:
- Sets up the MCP server connection
- Adds Figma-specific Agent Skills
- Configures best practices for design-to-code

**2. Verify installation:**
```bash
claude plugin list
```

You should see `figma@claude-plugins-official` in the list.

**3. Start Claude Code and test:**
```bash
cd ~/Projects/Memo
claude
```

In Claude, type:
```
/mcp
```

Select `figma` and click **Authenticate** → **Allow Access**.

✅ **Done!** You're now connected.

---

### Option 2: Manual Setup (More Control)

**1. Add Figma MCP server to Claude Code:**
```bash
claude mcp add --scope user --transport http figma https://mcp.figma.com/mcp
```

The `--scope user` flag makes it available across all projects (not just Memo).

**2. Start Claude Code:**
```bash
cd ~/Projects/Memo
claude
```

**3. Authenticate:**
Type `/mcp` in Claude → select `figma` → **Authenticate** → **Allow Access**

---

## How to Use Figma MCP

### Workflow: Figma → Code

#### 1. Create Designs in Figma

**Design the Memo app screens in Figma:**
- Search screen (with search bar, note cards, filters)
- Voice capture screen (record button, waveform visualization)
- Note detail screen (content, tags, source icon)
- Integrations list (Telegram, Notion, etc.)

Use Figma's auto-layout, components, and variants for best results.

#### 2. Convert Individual Screens

**Method A: Selection-based (in Figma desktop app)**
1. Select a frame in Figma (e.g., "Search Screen")
2. In Claude Code, prompt:
   ```
   Convert my current Figma selection to SwiftUI code for iOS.
   Use MVVM architecture. Include @StateObject for ViewModel.
   Match the exact spacing, colors, and typography from the design.
   ```

**Method B: Link-based (works anywhere)**
1. In Figma, select a frame
2. Copy the Figma link (Cmd+L or right-click → Copy link)
3. In Claude Code, prompt:
   ```
   Convert this Figma design to SwiftUI:
   https://figma.com/file/abc123/SearchScreen?node-id=1:2
   
   Use MVVM, match design tokens exactly, add placeholder data.
   ```

#### 3. Extract Design Tokens

**Get colors, spacing, typography from Figma:**
```
Extract all design tokens from this Figma file:
https://figma.com/file/abc123/Memo-Design-System

Create a SwiftUI DesignTokens.swift file with:
- Color assets
- Typography styles (SF Pro, sizes, weights)
- Spacing constants
- Corner radius values
```

Claude will generate:
```swift
// DesignTokens.swift
extension Color {
    static let memoBackground = Color(hex: "#F5F5F7")
    static let memoPrimary = Color(hex: "#007AFF")
    static let memoText = Color(hex: "#1C1C1E")
}

extension Font {
    static let memoTitle = Font.system(size: 28, weight: .bold)
    static let memoBody = Font.system(size: 17, weight: .regular)
}
```

---

## Advanced: Multi-Screen Flows

**For complex flows (e.g., onboarding carousel):**

1. Design all 3 onboarding screens in Figma (separate frames)
2. Prompt Claude:
   ```
   Convert these 3 Figma frames into a SwiftUI onboarding flow:
   
   Frame 1: https://figma.com/...
   Frame 2: https://figma.com/...
   Frame 3: https://figma.com/...
   
   Create a TabView with PageTabViewStyle. Add smooth transitions.
   Include skip/next buttons. Use MVVM pattern.
   ```

Claude will generate the complete flow in one go.

---

## Design-First Workflow for Memo

### Recommended Order (Based on YouTube Best Practices):

1. **Design in Figma** (Week 1)
   - Sketch all main screens (Search, Capture, Integrations, Settings)
   - Define color palette, typography, spacing
   - Create reusable components (buttons, cards, input fields)
   - Test responsive layouts (iPhone 15, iPhone SE)

2. **Extract Design Tokens** (Day 1 of Week 2)
   ```bash
   cd ~/Projects/Memo/ios/Memo
   claude
   ```
   
   Prompt:
   ```
   Extract design tokens from https://figma.com/file/[your-file]
   Create DesignTokens.swift with Color, Font, Spacing extensions.
   ```

3. **Convert Screens to Code** (Week 2)
   - Start with simplest screen (Settings or Integrations list)
   - Then Search screen (most complex UI)
   - Voice capture screen (audio visualization)
   - Note detail screen

4. **Wire Up ViewModels** (Week 3)
   - Add state management (@StateObject)
   - Connect to backend API
   - Handle loading/error states

5. **Iterate in Figma → Re-sync** (Ongoing)
   - Update designs based on testing
   - Re-convert affected screens
   - Claude will preserve your logic, update only UI

---

## Pro Tips

### 1. Organize Figma Files
```
Memo Design System/
├── 📄 Design Tokens (colors, typography, spacing)
├── 🧩 Components (buttons, cards, inputs)
└── 📱 Screens (all app screens)
```

### 2. Use Figma Auto-Layout
- Claude understands SwiftUI stacks (VStack, HStack, ZStack)
- Figma's auto-layout maps directly to these
- Add constraints for responsive behavior

### 3. Name Layers Clearly
Bad: `Rectangle 1`, `Group 12`  
Good: `SearchBar`, `NoteCard`, `CaptureButton`

Claude uses layer names to generate variable names.

### 4. Add Component Descriptions
In Figma, add descriptions to components explaining their behavior:
- "Primary button - tappable, shows loading spinner on tap"
- "Note card - displays note preview, tappable to view full note"

Claude will generate appropriate logic.

### 5. Use Variants for States
Create button variants:
- Default
- Hover
- Pressed
- Disabled
- Loading

Claude will generate SwiftUI states automatically.

---

## Avoiding AI Slop with Figma MCP

### ❌ Don't Do This:
- Generic Figma templates from community
- Random color palettes
- Default spacing (8px everywhere)
- Stock SF Symbols without customization

### ✅ Do This Instead:
- **Custom color palette** - Choose intentional colors (ADHD-friendly: calming blues/greens)
- **Thoughtful spacing** - Vary padding (16px, 20px, 24px) based on hierarchy
- **Custom iconography** - Modify SF Symbols or design unique icons
- **Branded components** - Make buttons, cards feel like "Memo" (not generic iOS)

**Example: Custom Note Card**
Instead of generic rounded rectangle + text:
- Add subtle shadow (not harsh drop shadow)
- Custom corner radius (12px, not default 8px)
- Source icon in top-left (Telegram blue, Notion black/white)
- Tag pills with unique shape (rounded ends, 6px padding)
- Micro-interaction on tap (scale to 0.98)

---

## Troubleshooting

### "MCP server not found"
```bash
# Check if server is installed
claude mcp list

# Reinstall if missing
claude plugin install figma@claude-plugins-official
```

### "Authentication failed"
1. Open Figma desktop app → Preferences
2. Enable "Dev Mode MCP Server"
3. Re-authenticate in Claude: `/mcp` → `figma` → Authenticate

### "Can't access Figma file"
- Make sure you have edit or view access to the file
- Try copying the link again (select frame first)

### Generated code doesn't match design
- Add more specific prompts: "Match EXACT spacing from Figma (use 20px not 16px)"
- Extract design tokens first, then reference them in prompts
- Use Figma's inspect panel to verify values

---

## Example Prompts for Memo

### Converting Search Screen
```
Convert this Figma search screen to SwiftUI:
https://figma.com/file/[link]

Requirements:
- MVVM architecture with SearchViewModel
- Use @StateObject for ViewModel
- Search bar at top (with SF Symbol magnifyingglass)
- List of NoteCards below (lazy loading)
- Empty state when no results
- Match exact colors, spacing, typography from Figma
- Add haptic feedback on tap
- Support dark mode
```

### Extracting Components
```
Extract the NoteCard component from this Figma file:
https://figma.com/file/[link]

Create a reusable SwiftUI view:
- Props: title, summary, tags, source, date
- Support different sources (Telegram blue, Notion black, Voice purple)
- Tappable with scale animation (0.98)
- Corner radius 12px, shadow (y: 2px, blur: 8px, opacity: 0.08)
```

### Design System Setup
```
Create a complete design system from this Figma file:
https://figma.com/file/[link]

Generate:
1. DesignTokens.swift - colors, fonts, spacing
2. ComponentLibrary/ - reusable views (buttons, cards, inputs)
3. Preview examples for each component
4. Dark mode support
```

---

## Resources

- **Figma MCP Official Docs:** https://developers.figma.com/docs/figma-mcp-server/
- **Claude Code Plugins:** https://claude.com/blog/claude-code-plugins
- **YouTube Tutorial:** https://www.youtube.com/watch?v=adVJ0DBNOAw (Figma to App Store in 37 minutes)
- **Builder.io Guide:** https://www.builder.io/blog/claude-code-figma-mcp-server

---

## Next Steps

1. [ ] Install Figma plugin: `claude plugin install figma@claude-plugins-official`
2. [ ] Create Figma file: "Memo Design System"
3. [ ] Design 1 screen (start with Settings - simplest)
4. [ ] Convert to SwiftUI with Claude
5. [ ] Test on iPhone simulator
6. [ ] Iterate and refine

**Pro tip:** Start with ONE screen. Get the workflow down. Then scale to all screens. Don't design everything in Figma first — iterate in cycles (design → code → test → refine).

---

**Last Updated:** March 12, 2026
