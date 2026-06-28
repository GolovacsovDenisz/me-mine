# Flutter Interview Cheat Sheet — Denisz (keep open beside test)

---

## ⚡ DART ASYNC — YOUR #1 WEAK SPOT

### Event loop order (always trace in this order)
```
1. ALL sync code in current function
2. Microtask queue  (Future.microtask, scheduleMicrotask)
3. Event queue      (Future(() => ...), Future.delayed, await continuations)
```

### 4 patterns — memorize

| Pattern | Rule | Example output |
|---------|------|----------------|
| Sync vs Future | Sync prints first | `print 1; Future(()=>print 2); print 3` → **1, 3, 2** |
| await | Pauses THIS function only — NOT whole queue | Other Futures still run while paused |
| delayed(zero) | Still async — after microtasks | **NOT** instant |
| Loop + Future | Loop finishes sync first, then Futures run | See trap below ↓ |

### await trap (you got this wrong once — re-read!)
```dart
Future<void> main() async {
  print('1');
  Future(() => print('2'));      // scheduled, NOT awaited
  await Future(() => print('3')); // pause HERE — '4' is NOT sync with '1'
  print('4');
}
// Answer: 1, 2, 3, 4   (NOT 1, 4, 2, 3)
```

### Loop + Future trap — TWO VERSIONS

```dart
// ✅ Dart default — fresh i each iteration
for (var i = 0; i < 3; i++) {
  Future(() => print(i));
}
// → done, 0, 1, 2

// ⚠️ TRAP — i declared OUTSIDE
var i;
for (i = 0; i < 3; i++) {
  Future(() => print(i));
}
print('done');
// → done, 3, 3, 3   (i ends at 3, all closures share it)
```

### Future vs Stream
| | Future | Stream |
|---|--------|--------|
| Values | **One** | **Many over time** |
| Widget | FutureBuilder | StreamBuilder |
| Riverpod | FutureProvider | StreamProvider |

---

## NULL SAFETY

| Op | Meaning |
|----|---------|
| `String?` | Can be null |
| `!` | Force unwrap (crashes if null) |
| `??` | Fallback: `name ?? 'Guest'` |
| `?.` | Safe call: `user?.name` |
| `late` | Declare now, assign before use |

## var / final / const

| | Reassign? | Compile-time constant? |
|---|-----------|------------------------|
| `var` | ✅ | ❌ |
| `final` | ❌ | ❌ (runtime OK) |
| `const` | ❌ | ✅ |

---

## FLUTTER FUNDAMENTALS

### Stateless vs Stateful
- **Stateless** = no internal mutable state; rebuilds when parent/inherited widgets change
- **Stateful** = owns changing state (`setState`, controllers)

### Lifecycle
```
initState (once, setup) → build (many times) → dispose (cleanup)
```
- ❌ Never `setState` inside `initState`

### Lists
- **ListView.builder** = lazy, only visible items — use for 500+ items
- **ListView(children: [...])** = builds ALL children at once
- **Column** = no scroll, builds everything

### Async UI
- One-shot fetch → **FutureBuilder** / **AsyncValue.when**
- Live updates → **StreamBuilder** / **StreamProvider**

### Hot reload vs restart
- **Hot reload** = fast code swap, **keeps state** (controllers alive)
- **Hot restart** = reruns `main()`, **loses state**
- **const** widgets may need hot **restart** to pick up constructor changes

### Keys (you were shaky here)
- Problem: delete row → checkbox state jumps to wrong row
- Fix: `Key(ValueKey(entry.id))` on each row
- Why: Flutter tracks **identity**, not just list **index**

### const widgets
- Reused across rebuilds → less work, better performance

---

## RIVERPOD — YOUR APP

### When to use what
| Provider type | Use for | Me Mine example |
|---------------|---------|-----------------|
| `Provider` | DI — stable service, no rebuild | `entriesRepositoryProvider` |
| `StreamProvider` | Live data stream | `recentPastEntriesProvider` |
| `StreamProvider.family` | Stream per parameter | `entryByDateIdProvider(dateId)` |
| `NotifierProvider` | Mutable state + methods | `passcodePrefsProvider` |

### watch vs read vs listen
```dart
// IN build() — subscribe, rebuild on change
final x = ref.watch(myProvider);

// IN onPressed / callbacks — one-shot, no subscribe
ref.read(myProvider);
ref.read(myProvider.notifier).someMethod();

// Side effects only (snackbar, sync form) — NOT for normal display
ref.listen(myProvider, (prev, next) { ... });
```

### AsyncValue states
```dart
async.when(
  loading: () => CircularProgressIndicator(),
  error: (e, st) => Text('Error'),
  data: (value) => MyWidget(value),
);
```

### .family
- One provider definition, **separate cached state per parameter**
- `ref.watch(entryByDateIdProvider('2025-06-21'))`

---

## CLEAN ARCHITECTURE

```
Presentation  →  screens, widgets, Riverpod
Domain        →  entities, repo interfaces (PURE DART — no Flutter!)
Data          →  repo impl, Firebase, SQLite, HTTP, fromJson
```

### Where do API/Firebase calls go?
→ **Data layer** (repository impl + datasources)

### Why NOT Firebase in widgets?
1. Tight coupling — can't swap/test
2. Can't do offline-first cleanly
3. UI mixed with parsing/sync logic

### Me Mine offline-first
```
Write → SQLite immediately (instant, works offline)
      → Firestore syncs in background when online
      → UI watches StreamProvider → updates
```

### JSON flow
```
http.get → jsonDecode → Model.fromJson → map to domain Entity → repository → provider → UI
```

---

## CODING TEMPLATES — TYPE FROM MEMORY

### JSON parse
```dart
import 'dart:convert';

class Entry {
  Entry({required this.id, required this.title, required this.mood});
  final String id;
  final String title;
  final int mood;

  factory Entry.fromJson(Map<String, dynamic> json) => Entry(
    id: json['id'] as String,
    title: json['title'] as String,
    mood: json['mood'] as int,
  );
}

void main() {
  const s = '{"id":"1","title":"My day","mood":4}';
  final entry = Entry.fromJson(jsonDecode(s) as Map<String, dynamic>);
  print(entry.title);
}
```

### Async fetch
```dart
Future<Entry?> fetchEntry(String url) async {
  try {
    final res = await http.get(Uri.parse(url));
    if (res.statusCode == 200) {
      return Entry.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
    }
    return null;
  } catch (e) {
    return null;
  }
}
```

### Filter list
```dart
final filtered = entries.where((e) => e.mood >= 4).toList();
```

---

## SPOKEN INTERVIEW — ONE-LINERS

**About you:** EU, Hungary, remote OK, start immediately, ~9 months hands-on, Me Mine portfolio.

**Me Mine:** Offline-first journal — SQLite local, Firebase sync, Riverpod, GoRouter, Clean Architecture, AI mood analytics.

**Riverpod:** Separates UI from data; Provider for DI, StreamProvider for live data, NotifierProvider for settings; testable with overrides.

**Experience:** 9 months — Udemy + real app with auth, SQLite, Firebase, navigation. Junior, learning fast, ship features.

**AI tools:** Cursor for boilerplate; I read and understand code; architecture decisions are mine.

---

## FLOWMINGO — RESUME DEEP-DIVES (memorize these!)

### Offline-first sync (YOUR #1 CV question)
1. Save → **SQLite first**, row marked `pending`
2. UI reads **SQLite stream** (instant, works offline)
3. Background → push to Firestore (`unawaited`)
4. Online again → sync all **pending** rows → mark **synced**
5. Firestore listeners pull remote → merge to SQLite
6. **Conflict:** if local is `pending`, **local wins**

**One-liner:** SQLite = source of truth for reads; pending flag tracks upload queue.

### Passcode security (YOU MUST KNOW THIS)
| Store | Never store |
|-------|-------------|
| SHA-256 **hash** in Flutter Secure Storage | Plaintext PIN |
| Flags: enabled, biometric allowed (SharedPreferences) | PIN in Firestore/logs |

- Setup: PIN → SHA-256 hash → secure storage
- Unlock: hash entered PIN → compare to stored hash
- Biometrics: `local_auth` unlocks **session** (not stored PIN)
- App backgrounded → session **locks** again

### Gemini via Cloud Functions (why not client?)
- API key in app = extractable (reverse engineering)
- Key stays server-side as Firebase **secret**
- App calls `analyzePeriod` Cloud Function only
- Update prompt/model without app release + auth check first

### Career switch (inventory → dev)
- Wanted growth, remote flexibility, problem-solving work
- Inventory taught: **accuracy, deadlines, international teams** (India, Germany, China…)
- Don't say old job was "boring" — say "I wanted to build things"

### Cursor / AI tools
- AI for **boilerplate**, not architecture decisions
- I **accept/reject** every change; I read code before shipping
- Use AI **mentor-style**: "what's the better approach and why?"

---

## ASYNC TRACE CHECKLIST (use on every print puzzle)
- [ ] Run all sync lines top to bottom
- [ ] List what got scheduled (microtask vs event queue)
- [ ] Is there `await`? Code AFTER it is NOT sync
- [ ] Is `i` inside or outside the loop?
- [ ] Event queue = FIFO (first scheduled runs first)

---

*Good luck — Denisz*
