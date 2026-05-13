---
name: design-pattern-iterator
description: Iterator traverses collection elements without exposing structure. Use when collection has complex structure, multiple traversal algorithms, or client should not depend on internals.
---

# Iterator

## Intent

Traverse collection elements without exposing underlying representation (list, stack, tree). Several iterators can traverse same collection independently.

## Problem

- Collections have different structures (list, tree, graph)
- Need different traversals (depth-first, breadth-first)
- Adding algorithms to collection blurs responsibility
- Client coupled to collection classes to access elements

## Solution

1. Extract traversal into separate iterator object
2. Iterator encapsulates current position, remaining elements
3. Single method to fetch next (e.g. `next()`, `getNext()`)
4. All iterators share interface; client works with any collection via iterator
5. Collection provides factory method for iterators

## When to Use

- Complex structure; hide from client (convenience or security)
- Reduce duplication of traversal code
- Traverse different structures with same client code

## Structure (TypeScript)

```ts
interface CustomIterator<T> {
  getNext(): T | undefined;
  hasMore(): boolean;
}

class ArrayIterator<T> implements CustomIterator<T> {
  private position = 0;
  constructor(private items: T[]) {}
  getNext(): T | undefined {
    return this.hasMore() ? this.items[this.position++] : undefined;
  }
  hasMore(): boolean {
    return this.position < this.items.length;
  }
}

interface SocialNetwork {
  createFriendsIterator(profileId: string): ProfileIterator;
  createCoworkersIterator(profileId: string): ProfileIterator;
}
```

## Pros / Cons

**Pros:** Delay iteration; parallel iteration (own state); OCP; SRP.

**Cons:** Overkill for simple collections; may be less efficient.

## Relations

- Iterator for Composite tree traversal
- Factory Method for creating iterators in collections
- Memento for capturing iteration state
- Visitor + Iterator for traversing and operating

## References

- [Refactoring Guru](https://refactoring.guru/design-patterns/iterator)
- [TypeScript example](https://refactoring.guru/design-patterns/iterator/typescript/example)
