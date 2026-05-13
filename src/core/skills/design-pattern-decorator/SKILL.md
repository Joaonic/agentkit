---
name: design-pattern-decorator
description: Decorator attaches new behaviors by wrapping objects. Interface stays same or extended; supports recursive composition. Use when adding behavior at runtime without inheritance, or when subclass explosion for combinations.
---

# Decorator

Also known as: Wrapper

## Intent

Attach new behaviors to objects by placing them inside wrapper objects. Decorator implements same interface as wrapped object; can wrap components and other decorators (stack).

## Problem

- Need to combine behaviors (Email + SMS + Slack notifications)
- Inheritance: one parent; static—can't alter at runtime
- Subclass per combination → explosion

## Solution

Use composition: wrapper has reference to wrapped object, delegates work, adds behavior before/after. Same interface → client treats decorated and plain object identically. Stack multiple decorators.

Base decorator delegates all to wrapped; concrete decorators add behavior in overrides.

## When to Use

- Assign extra behaviors at runtime without breaking clients
- Awkward or impossible to extend with inheritance (final class)
- Structure logic into layers; compose at runtime

## Structure (TypeScript)

```ts
interface DataSource {
  writeData(data: string): void;
  readData(): string;
}

class FileDataSource implements DataSource {
  constructor(private filename: string) {}
  writeData(d: string) {
    /* write to file */
  }
  readData() {
    /* read from file */
  }
}

class DataSourceDecorator implements DataSource {
  constructor(protected wrappee: DataSource) {}
  writeData(d: string) {
    this.wrappee.writeData(d);
  }
  readData() {
    return this.wrappee.readData();
  }
}

class EncryptionDecorator extends DataSourceDecorator {
  writeData(d: string) {
    this.wrappee.writeData(/* encrypt */ d);
  }
  readData() {
    return /* decrypt */ this.wrappee.readData();
  }
}

let source: DataSource = new FileDataSource('file.dat');
source = new EncryptionDecorator(source);
source.writeData('sensitive');
```

## Pros / Cons

**Pros:** SRP; combine behaviors; add/remove at runtime; no subclass explosion.

**Cons:** Initial config can be messy; decorator order may matter; hard to remove specific wrapper.

## Relations

- Decorator vs Adapter: Adapter changes interface; Decorator extends/same
- Decorator vs Proxy: Proxy manages lifecycle; Decorator composition controlled by client
- Decorator changes skin; Strategy changes guts

## References

- [Refactoring Guru](https://refactoring.guru/design-patterns/decorator)
- [TypeScript example](https://refactoring.guru/design-patterns/decorator/typescript/example)
