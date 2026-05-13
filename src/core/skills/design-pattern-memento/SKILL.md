---
name: design-pattern-memento
description: Memento captures and restores object state without breaking encapsulation. Use for undo, snapshots, transactions. Originator creates memento; caretaker stores it.
---

# Memento

Also known as: Snapshot

## Intent

Save and restore previous state without revealing implementation. Delegate snapshot creation to the owner (originator).

## Problem

- Need undo: save state before operation
- Copying from outside fails with private fields
- Exposing state for copying breaks encapsulation

## Solution

1. **Memento**: value object holding originator state; immutable; created via constructor
2. **Originator**: `createSnapshot()` → memento; `restore(memento)` from memento
3. **Caretaker**: knows when to capture/restore; stores stack of mementos
4. Only originator accesses memento internals; caretaker uses limited interface (e.g. metadata)

Nested class (if language supports) lets originator access private memento fields.

## When to Use

- Produce snapshots to restore previous state
- Direct field access violates encapsulation
- Transactions (rollback on error)

## Structure (TypeScript)

```ts
class Snapshot {
  constructor(
    private editor: Editor,
    private text: string,
    private curX: number,
    private curY: number,
    private selectionWidth: number
  ) {}
  restore() {
    this.editor.setText(this.text);
    this.editor.setCursor(this.curX, this.curY);
    this.editor.setSelectionWidth(this.selectionWidth);
  }
}

class Editor {
  createSnapshot(): Snapshot {
    return new Snapshot(this, this.text, this.curX, this.curY, this.selectionWidth);
  }
}

class Command {
  private backup?: Snapshot;
  makeBackup() {
    this.backup = this.editor.createSnapshot();
  }
  undo() {
    this.backup?.restore();
  }
}
```

## Pros / Cons

**Pros:** Simplify originator; snapshots without breaking encapsulation.

**Cons:** Dynamic languages may not guarantee memento immutability; caretaker must track lifecycle; RAM if many mementos.

## Relations

- Command + Memento for undo
- Memento + Iterator for rollback of iteration state
- Prototype as simpler alternative for straightforward objects

## References

- [Refactoring Guru](https://refactoring.guru/design-patterns/memento)
- [TypeScript example](https://refactoring.guru/design-patterns/memento/typescript/example)
