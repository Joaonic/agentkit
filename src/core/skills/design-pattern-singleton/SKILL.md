---
name: design-pattern-singleton
description: Singleton ensures a class has only one instance with global access. Use for shared resources (DB, file), but prefer DI in hexagonal apps for testability. Handles multithreading carefully.
---

# Singleton

## Intent

Ensure a class has only one instance and provide global access to it. Violates SRP (solves instance control + access in one pattern).

## Problem

- Control access to shared resource (DB, file)
- Provide global access point (without unsafe global variables)
- Constructor always returns new object—need different mechanism

## Solution

1. Private constructor (prevents external `new`)
2. Static creation method (`getInstance`) that returns cached instance
3. First call creates and caches; subsequent calls return cache
4. Multithreading: double-checked locking or similar to avoid multiple instances

## When to Use

- Single instance for all clients (e.g. shared DB)
- Stricter control than global variables
- **Caution:** Hinders unit testing (mocks), can mask bad design. Prefer DI in hexagonal/NestJS.

## Structure (TypeScript)

```ts
class Database {
  private static instance: Database;

  private constructor() {
    // Init connection
  }

  static getInstance(): Database {
    if (!Database.instance) {
      Database.instance = new Database();
    }
    return Database.instance;
  }

  query(sql: string) {
    /* ... */
  }
}

const foo = Database.getInstance();
const bar = Database.getInstance();
// foo === bar
```

## Pros / Cons

**Pros:** Lazy init; global access; single instance guaranteed.

**Cons:** Hard to unit test; multithreading complexity; can hide coupling; violates SRP.

## Relations

- Facade often becomes Singleton
- Singleton vs Flyweight: Singleton mutable, one instance; Flyweight immutable, multiple instances with different intrinsic state

## References

- [Refactoring Guru](https://refactoring.guru/design-patterns/singleton)
- [TypeScript example](https://refactoring.guru/design-patterns/singleton/typescript/example)
