# Vibecast — Agent Instructions

## Project

Native iOS podcast app built with Swift and SwiftUI. See `specs/app-spec.md` for product requirements and `docs/superpowers/specs/2026-04-19-vibecast-mvp-design.md` for the full MVP design.

## Language & Platform

- Swift 5.9+, SwiftUI, SwiftData
- iOS 17.0 minimum deployment target
- iPhone first; no iPad-specific layout required for MVP

## Code Style

- Follow Swift API Design Guidelines: clear, expressive names over brevity
- `camelCase` for variables and functions, `PascalCase` for types
- No `var` when `let` works
- Prefer `guard` for early returns over nested `if`
- No force unwraps (`!`) except in `#Preview` blocks and test setup (`try!`, `XCTUnwrap` preferred in tests)
- No comments that restate what the code does — only explain non-obvious *why*

## Architecture

- `@Model` (SwiftData) for persistent entities: `Podcast`, `Episode`
- `@Observable` ViewModels own business logic and mediate between `ModelContext` and views
- SwiftUI views are pure layout — no business logic, no direct `ModelContext` access except via `@Environment`
- All secondary screens are SwiftUI sheets, not pushed `NavigationLink` destinations
- No tab bar for MVP

## SwiftUI Conventions

- Use `ViewThatFits` for adaptive layouts that respond to content height
- Use `.onTapGesture` instead of nested `Button` inside `List` rows to avoid tap-target conflicts
- Use `.swipeActions` for row gestures (not deprecated `onDelete`)
- Use `.presentationDetents([.large])` and `.presentationDragIndicator(.visible)` on sheets
- Prefer `AsyncImage` for remote artwork; always provide a placeholder
- Keep views small and focused — extract sub-views as `private var` or `private func` returning `some View`

## SwiftData Conventions

- All `@Model` classes are `final`
- Use `@Relationship(deleteRule: .cascade)` on parent-owned collections
- ViewModels take `ModelContext` as an `init` parameter (never access `@Environment` directly)
- Tests use `ModelConfiguration(isStoredInMemoryOnly: true)` — never write to disk in tests

## Testing

- XCTest for all ViewModel and model logic
- Test files mirror source structure: `VibecaastTests/ViewModels/SubscriptionsViewModelTests.swift`
- Test method names follow `test_subject_condition_expectation` convention
- All test classes are `@MainActor final class`
- Use `SampleData.insertSampleData(into:)` to seed test contexts — never hardcode data inline
- No UI snapshot tests for MVP

## TDD Workflow

1. Write the failing test
2. Run it — confirm it fails for the right reason
3. Write the minimal implementation to make it pass
4. Run it — confirm it passes
5. Commit

## Commits

- Prefix: `feat:`, `fix:`, `refactor:`, `test:`, `docs:`
- Subject line: imperative, ≤72 characters
- One logical change per commit
- Always run tests before committing

## File Organisation

```
Vibecast/
├── Models/          — SwiftData @Model classes
├── ViewModels/      — @Observable business logic
├── Views/           — SwiftUI views and components
└── Preview Content/ — SampleData.swift only

VibecaastTests/
├── ModelTests.swift
└── SubscriptionsViewModelTests.swift
```

## What Not To Do

- Do not add features not in the current plan or spec
- Do not use `UIKit` directly unless SwiftUI has no equivalent
- Do not access the network in tests
- Do not use `DispatchQueue` — use Swift concurrency (`async`/`await`) if async work is needed
- Do not create files outside the structure above without a clear reason
- Do not skip the test step — if a function has logic, it has a test
