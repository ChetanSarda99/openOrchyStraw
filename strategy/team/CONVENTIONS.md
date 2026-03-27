# CONVENTIONS.md - Code Style Guide for Memo

## General Principles

1. **Clarity over cleverness** - ADHD-friendly code (easy to scan, understand)
2. **Consistency** - Follow established patterns
3. **TypeScript/Swift strict mode** - No `any`, no force unwraps
4. **Descriptive names** - `fetchUserNotes()` not `getData()`
5. **Small functions** - Max 30 lines, one responsibility
6. **Comments for "why" not "what"** - Code should be self-documenting

---

## TypeScript / Node.js Backend

### File Naming
- `camelCase.ts` for files
- `PascalCase.ts` for classes/models
- `kebab-case/` for folders

### Code Style
```typescript
// ✅ Good
interface Note {
  id: string;
  content: string;
  createdAt: Date;
}

async function fetchUserNotes(userId: string): Promise<Note[]> {
  const notes = await prisma.note.findMany({
    where: { userId },
    orderBy: { createdAt: 'desc' },
  });
  
  return notes;
}

// ❌ Bad
async function getData(id: any): Promise<any> {
  const data = await prisma.note.findMany({ where: { userId: id } });
  return data;
}
```

### Error Handling
```typescript
// ✅ Good - explicit error types
class NotFoundError extends Error {
  constructor(message: string) {
    super(message);
    this.name = 'NotFoundError';
  }
}

async function getNote(id: string): Promise<Note> {
  const note = await prisma.note.findUnique({ where: { id } });
  
  if (!note) {
    throw new NotFoundError(`Note ${id} not found`);
  }
  
  return note;
}

// ❌ Bad - generic errors
async function getNote(id: string): Promise<Note | null> {
  try {
    return await prisma.note.findUnique({ where: { id } });
  } catch (e) {
    console.log('Error:', e);
    return null;
  }
}
```

### Async/Await
- Always use `async/await` (no `.then()` chains)
- Handle errors explicitly (no silent catches)

```typescript
// ✅ Good
async function syncTelegram(userId: string): Promise<void> {
  const credentials = await getCredentials(userId);
  const messages = await telegram.fetchMessages(credentials);
  
  for (const msg of messages) {
    await saveNote(msg);
  }
}

// ❌ Bad
function syncTelegram(userId: string): Promise<void> {
  return getCredentials(userId)
    .then(creds => telegram.fetchMessages(creds))
    .then(messages => {
      messages.forEach(msg => saveNote(msg)); // Not awaited!
    })
    .catch(err => console.log(err)); // Silent error
}
```

### Environment Variables
```typescript
// ✅ Good - validate on startup
const config = {
  port: parseInt(process.env.PORT || '3000', 10),
  anthropicApiKey: requireEnv('ANTHROPIC_API_KEY'),
  databaseUrl: requireEnv('DATABASE_URL'),
};

function requireEnv(key: string): string {
  const value = process.env[key];
  if (!value) {
    throw new Error(`Missing required env var: ${key}`);
  }
  return value;
}

// ❌ Bad - runtime failures
const apiKey = process.env.API_KEY; // Might be undefined!
```

---

## Swift / iOS App

### File Naming
- `PascalCase.swift` for all files
- Group by feature (not by type)

```
Views/
├── Search/
│   ├── SearchView.swift
│   ├── SearchViewModel.swift
│   └── SearchRow.swift
└── Capture/
    ├── VoiceCaptureView.swift
    └── VoiceCaptureViewModel.swift
```

### SwiftUI Code Style
```swift
// ✅ Good - clear hierarchy, explicit types
struct SearchView: View {
    @StateObject private var viewModel = SearchViewModel()
    @State private var searchQuery = ""
    
    var body: some View {
        NavigationStack {
            List(viewModel.notes) { note in
                SearchRow(note: note)
            }
            .searchable(text: $searchQuery)
            .navigationTitle("Search")
            .task {
                await viewModel.loadNotes()
            }
        }
    }
}

// ❌ Bad - unclear, implicit
struct SearchView: View {
    @StateObject var vm = SearchViewModel()
    @State var q = ""
    
    var body: some View {
        List(vm.notes, id: \.id) { n in
            Text(n.content)
        }
    }
}
```

### Naming Conventions
- **Views:** `[Feature]View.swift` (e.g., `SearchView`, `NoteDetailView`)
- **ViewModels:** `[Feature]ViewModel.swift`
- **Models:** `Note.swift`, `User.swift` (singular)
- **Services:** `APIService.swift`, `AudioService.swift`

### Property Wrappers
```swift
// State management
@State          // Local view state
@Binding        // Passed from parent
@StateObject    // ViewModel lifecycle tied to view
@ObservedObject // ViewModel owned by parent
@EnvironmentObject // App-wide state (e.g., User)

// ✅ Good usage
struct SearchView: View {
    @StateObject private var viewModel = SearchViewModel()
    @State private var showFilters = false
    
    var body: some View {
        // ...
    }
}

// ❌ Bad - @ObservedObject for new instance
struct SearchView: View {
    @ObservedObject var viewModel = SearchViewModel() // Wrong! Use @StateObject
}
```

### Async/Await in SwiftUI
```swift
// ✅ Good - use .task modifier
struct NoteListView: View {
    @StateObject private var viewModel = NoteListViewModel()
    
    var body: some View {
        List(viewModel.notes) { note in
            NoteRow(note: note)
        }
        .task {
            await viewModel.loadNotes()
        }
        .refreshable {
            await viewModel.refresh()
        }
    }
}

// ❌ Bad - onAppear with Task
struct NoteListView: View {
    var body: some View {
        List(viewModel.notes) { note in
            NoteRow(note: note)
        }
        .onAppear {
            Task {
                await viewModel.loadNotes() // Use .task instead
            }
        }
    }
}
```

### Error Handling
```swift
// ✅ Good - explicit error types
enum APIError: Error {
    case networkError
    case unauthorized
    case notFound
    case serverError(String)
}

func fetchNotes() async throws -> [Note] {
    let response = try await apiService.get("/notes")
    
    guard response.statusCode == 200 else {
        throw APIError.serverError("Status \(response.statusCode)")
    }
    
    return try JSONDecoder().decode([Note].self, from: response.data)
}

// ❌ Bad - silent failures
func fetchNotes() async -> [Note] {
    do {
        let response = try await apiService.get("/notes")
        return try JSONDecoder().decode([Note].self, from: response.data)
    } catch {
        print("Error fetching notes")
        return []
    }
}
```

---

## Database (Prisma)

### Model Naming
- Singular (e.g., `User` not `Users`)
- PascalCase
- Fields in camelCase

```prisma
// ✅ Good
model Note {
  id          String   @id @default(uuid())
  userId      String
  content     String   @db.Text
  createdAt   DateTime @default(now())
  
  user        User     @relation(fields: [userId], references: [id])
  
  @@index([userId, createdAt])
}

// ❌ Bad
model notes {
  note_id     String   @id
  user_id     String
  note_text   String
  created     DateTime
}
```

### Queries
```typescript
// ✅ Good - specific selection
const notes = await prisma.note.findMany({
  where: {
    userId,
    createdAt: { gte: lastWeek },
  },
  select: {
    id: true,
    content: true,
    summary: true,
    tags: true,
    createdAt: true,
  },
  orderBy: { createdAt: 'desc' },
  take: 20,
});

// ❌ Bad - fetching all fields, no pagination
const notes = await prisma.note.findMany({
  where: { userId },
});
```

---

## Git Commit Messages

### Format
```
<type>(<scope>): <subject>

<body (optional)>

<footer (optional)>
```

### Types
- `feat` - New feature
- `fix` - Bug fix
- `docs` - Documentation
- `style` - Code formatting (no logic change)
- `refactor` - Code restructuring
- `test` - Adding tests
- `chore` - Build/tooling changes

### Examples
```bash
# ✅ Good
feat(search): add semantic search with Voyage AI
fix(voice): handle audio recording permissions
docs(readme): update setup instructions
refactor(api): extract Telegram sync to service layer

# ❌ Bad
fixed bug
wip
asdf
```

---

## API Design

### REST Endpoints
- Use nouns (not verbs): `/notes` not `/getNotes`
- Plural for collections: `/notes`, `/users`
- Use HTTP methods correctly:
  - `GET` - Read
  - `POST` - Create
  - `PUT/PATCH` - Update
  - `DELETE` - Delete

```typescript
// ✅ Good
GET    /notes          // List notes
GET    /notes/:id      // Get note
POST   /notes          // Create note
PUT    /notes/:id      // Update note
DELETE /notes/:id      // Delete note

// ❌ Bad
GET /getNotes
POST /createNote
POST /deleteNote/:id
```

### Request/Response Format
```typescript
// ✅ Good - consistent structure
interface SuccessResponse<T> {
  data: T;
}

interface ErrorResponse {
  error: {
    code: string;
    message: string;
  };
}

// Example
app.get('/notes/:id', async (req, res) => {
  try {
    const note = await getNote(req.params.id);
    res.json({ data: note });
  } catch (error) {
    res.status(404).json({
      error: {
        code: 'NOT_FOUND',
        message: 'Note not found',
      },
    });
  }
});

// ❌ Bad - inconsistent
app.get('/notes/:id', async (req, res) => {
  const note = await getNote(req.params.id);
  if (note) {
    res.json(note);
  } else {
    res.send('not found');
  }
});
```

---

## Testing (When Added)

### Test File Naming
- `[fileName].test.ts` or `[fileName].spec.ts`
- Same folder as source file

### Test Structure
```typescript
describe('Search Service', () => {
  describe('semanticSearch', () => {
    it('should return notes matching query', async () => {
      // Arrange
      const userId = 'test-user';
      const query = 'ADHD productivity tips';
      
      // Act
      const results = await searchService.semanticSearch(query, userId);
      
      // Assert
      expect(results).toHaveLength(5);
      expect(results[0].content).toContain('ADHD');
    });
    
    it('should return empty array for no matches', async () => {
      const results = await searchService.semanticSearch('xyz123', 'test-user');
      expect(results).toHaveLength(0);
    });
  });
});
```

---

## Documentation

### Code Comments
```typescript
// ✅ Good - explain "why" not "what"
// Batch embeddings to reduce API calls (Voyage AI charges per request)
const embeddings = await voyage.embedBatch(texts);

// Cache search results for 5 minutes to reduce Pinecone queries
await redis.setex(cacheKey, 300, JSON.stringify(results));

// ❌ Bad - obvious comments
// Get notes from database
const notes = await prisma.note.findMany();

// Loop through notes
for (const note of notes) {
  // Process note
  await processNote(note);
}
```

### README Files
- Every folder should have a README.md if it contains more than 3 files
- Explain purpose, usage, dependencies

---

## Performance

### Database Queries
- Always add indexes for filtered/sorted fields
- Use `select` to fetch only needed fields
- Paginate large result sets

### API Calls
- Batch when possible (Voyage AI embeddings)
- Cache frequently accessed data (Redis)
- Use connection pooling (Prisma default)

### iOS
- Lazy load images
- Use `List` with `id` for performance
- Avoid expensive computations in `body` (use computed properties)

---

## Security Checklist

- [ ] No secrets in code (use .env)
- [ ] All API endpoints require authentication
- [ ] SQL injection prevented (Prisma handles this)
- [ ] XSS prevented (sanitize user input)
- [ ] Rate limiting enabled
- [ ] HTTPS only
- [ ] OAuth tokens encrypted
- [ ] User data isolated by userId

---

**Last Updated:** March 12, 2026
