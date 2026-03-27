# Contributing to Memo

Thanks for your interest in contributing to Memo — the ADHD-focused universal note aggregator. This guide covers everything you need to get started.

---

## Git Workflow

### Branching Strategy

| Branch | Purpose |
|--------|---------|
| `main` | Production-ready code. Deployed to App Store / Railway. |
| `develop` | Integration branch. All feature branches merge here first. |
| `feature/*` | New features (e.g., `feature/semantic-search`) |
| `bugfix/*` | Bug fixes (e.g., `bugfix/voice-memo-crash`) |
| `hotfix/*` | Urgent production fixes (branch from `main`, merge back to both `main` and `develop`) |

### Commit Messages

Use [Conventional Commits](https://www.conventionalcommits.org/) format:

```
<type>(<scope>): <short description>
```

**Types:**

| Type | When to use |
|------|-------------|
| `feat` | A new feature |
| `fix` | A bug fix |
| `docs` | Documentation only |
| `style` | Formatting, linting (no logic change) |
| `refactor` | Code restructuring (no behavior change) |
| `test` | Adding or updating tests |
| `chore` | Dependencies, CI, build config |
| `perf` | Performance improvements |

**Examples:**

```
feat(search): add semantic search with Voyage AI
fix(voice): handle audio recording permissions
docs(readme): update setup instructions
style: fix linting errors
refactor(api): simplify auth middleware
test(search): add unit tests for search service
chore: update dependencies
perf(db): add index on notes.created_at
```

Keep the subject line under 72 characters. Use the body for additional context when needed:

```
fix(sync): prevent duplicate notes during Telegram sync

Telegram's getUpdates API can return the same message across
consecutive polls if the offset isn't updated correctly. Added
deduplication check using message_id before inserting.

Closes #42
```

### Pull Request Process

1. Create a branch from `develop` (e.g., `feature/telegram-sync`)
2. Make your changes, committing with conventional commit messages
3. Push your branch and open a PR against `develop`
4. Fill in the PR template — include a description, screenshots for UI changes, and any testing notes
5. Automated checks run (linting, tests, type checking)
6. Request a review
7. Address feedback, push updates
8. Merge once approved (squash merge preferred for feature branches)
9. Delete the branch after merge

---

## Code Standards

### TypeScript (Backend)

- **Strict mode enabled** — no implicit `any`, strict null checks
- **No `any` types** — use proper interfaces, generics, or `unknown` with type guards
- **Async/await** over raw promises or callbacks
- **Explicit return types** on all exported functions
- **Error handling** — use custom error classes, never swallow errors silently

### Swift (iOS)

- Follow [Apple's Swift API Design Guidelines](https://www.swift.org/documentation/api-design-guidelines/)
- **MVVM pattern** — Views, ViewModels, Models, Services in separate directories
- **@Observable** macro for iOS 17+ state management
- **async/await** for all asynchronous work
- **SF Symbols** for icons (custom assets only when SF Symbols doesn't cover it)
- Prefer value types (`struct`) over reference types (`class`) unless you need identity

### Linting

| Tool | Config | Scope |
|------|--------|-------|
| ESLint | `backend/.eslintrc` | All TypeScript files |
| SwiftLint | `ios/.swiftlint.yml` | All Swift files |

Run linters before pushing:

```bash
# Backend
cd backend && npm run lint

# iOS
cd ios && swiftlint
```

### Formatting

**Backend (Prettier):**

- 2-space indentation
- Single quotes
- Trailing commas (`es5`)
- Semicolons
- 100-character print width

```bash
cd backend && npm run format
```

**iOS:** Xcode default formatting + SwiftLint rules.

### Testing

| Layer | Framework | Coverage Target |
|-------|-----------|-----------------|
| Backend | Jest | 80% for core logic (services, utils) |
| iOS | XCTest | 80% for core logic (ViewModels, services) |

```bash
# Run backend tests
cd backend && npm test

# Run with coverage
cd backend && npm run test:coverage
```

### Documentation

- **JSDoc** comments on all exported/public functions in TypeScript
- **Documentation comments** (`///`) on public Swift APIs
- Add a `README.md` to any directory containing more than 3 files
- Keep inline comments focused on *why*, not *what*

---

## Local Development

### Prerequisites

- Node.js 20+
- Xcode 15+ (macOS only, for iOS development)
- Docker Desktop (for PostgreSQL + Redis)
- Git

### Setup

```bash
# Clone
git clone https://github.com/ChetanSarda99/memo-app.git
cd memo-app

# Backend setup
cd backend
cp .env.example .env  # Fill in your API keys
npm install
npm run dev  # localhost:3000

# iOS setup
cd ios
open Memo.xcodeproj  # or open in Xcode
# Select simulator, press Run

# Database (Docker)
docker compose up -d  # PostgreSQL + Redis
cd backend && npm run migrate
```

### Environment Variables

Copy `backend/.env.example` to `backend/.env` and fill in:

| Variable | Description | Where to get it |
|----------|-------------|-----------------|
| `DATABASE_URL` | PostgreSQL connection string | Local Docker or Railway |
| `REDIS_URL` | Redis connection string | Local Docker or Railway |
| `ANTHROPIC_API_KEY` | Claude API key | [console.anthropic.com](https://console.anthropic.com) |
| `VOYAGE_API_KEY` | Voyage AI key | [dash.voyageai.com](https://dash.voyageai.com) |
| `ASSEMBLYAI_API_KEY` | AssemblyAI key | [assemblyai.com](https://www.assemblyai.com) |
| `PINECONE_API_KEY` | Pinecone vector DB key | [app.pinecone.io](https://app.pinecone.io) |
| `JWT_SECRET` | Secret for signing tokens | Generate with `openssl rand -hex 32` |

Never commit `.env` files. They are in `.gitignore`.

### Useful Commands

```bash
# Backend
npm run dev          # Start dev server with hot reload
npm run build        # Compile TypeScript
npm run lint         # Run ESLint
npm run format       # Run Prettier
npm test             # Run Jest tests
npm run migrate      # Run Prisma migrations
npm run studio       # Open Prisma Studio (DB browser)

# Docker
docker compose up -d    # Start PostgreSQL + Redis
docker compose down     # Stop containers
docker compose logs -f  # Tail container logs
```

---

## Pull Request Guidelines

- **Keep PRs focused.** One feature or one fix per PR. If a PR touches more than 10 files, consider splitting it.
- **Include screenshots** for any UI changes (before/after if modifying existing UI).
- **Update documentation** if your change alters behavior, adds a new endpoint, or changes configuration.
- **Never commit secrets.** No `.env` files, API keys, tokens, or credentials. If you accidentally commit one, rotate it immediately.
- **Run the linter before pushing.** PRs that fail lint checks will be blocked.
- **Write meaningful PR descriptions.** Explain what changed, why, and how to test it.
- **Link issues.** If your PR addresses an issue, reference it with `Closes #123`.

### PR Description Template

```markdown
## What

Brief description of the change.

## Why

Context on why this change is needed.

## How

Implementation approach and key decisions.

## Screenshots

(For UI changes — before/after)

## Testing

How you tested this change.

## Checklist

- [ ] Linter passes
- [ ] Tests pass
- [ ] Documentation updated (if applicable)
- [ ] No secrets committed
```

---

## Issue Guidelines

- **Search first.** Check existing issues before creating a new one to avoid duplicates.
- **Use templates.** Choose the appropriate template: Bug Report, Feature Request, or Question.
- **Be specific.** For bugs, include:
  - Steps to reproduce
  - Expected behavior
  - Actual behavior
  - Device / OS / app version
  - Screenshots or logs if available
- **Label appropriately.** Use labels like `bug`, `feature`, `enhancement`, `documentation`, `good first issue`.
- **One issue per issue.** Don't bundle multiple bugs or requests into a single issue.

### Bug Report Template

```markdown
**Describe the bug**
A clear description of what went wrong.

**Steps to reproduce**
1. Go to '...'
2. Tap on '...'
3. See error

**Expected behavior**
What should have happened.

**Actual behavior**
What actually happened.

**Screenshots / Logs**
If applicable.

**Environment**
- Device: iPhone 15
- iOS version: 17.4
- App version: 0.1.0
```

### Feature Request Template

```markdown
**Problem**
What problem does this solve? Who is it for?

**Proposed solution**
How should it work?

**Alternatives considered**
Other approaches you thought about.

**Additional context**
Mockups, examples, references.
```

---

## Questions?

- Check the `docs/` folder for detailed specs and architecture docs
- Review `ARCHITECTURE.md` for system design
- Read `CONVENTIONS.md` for code style details
- Open an issue with the `question` label
