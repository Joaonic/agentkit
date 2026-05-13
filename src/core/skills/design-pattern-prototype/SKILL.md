---
name: design-pattern-prototype
description: Prototype copies existing objects without coupling to their classes. Use when code works with objects via interface (concrete class unknown), to avoid subclass explosion for config presets, or when cloning is cheaper than construction.
---

# Prototype

Also known as: Clone

## Intent

Copy existing objects without making code dependent on their classes. Prototype delegates cloning to the objects being cloned.

## Problem

- Copying from outside fails with private fields
- Knowing the class to duplicate creates dependency
- Subclass explosion for config presets

## Solution

1. Declare `clone()` in a common interface
2. Each class implements cloning (creates same-class instance, copies fields)
3. Client clones via interface; doesn't need to know concrete class
4. **Prototype Registry** (optional): catalog of pre-built prototypes for lookup by key

Use copy constructor (constructor that accepts same-type object) for safe cloning—return fully built object.

## When to Use

- Code shouldn't depend on concrete classes of objects to copy
- Reduce subclasses that only differ in initialization
- Pre-built objects configured various ways as prototypes; clone instead of subclass

## Structure (TypeScript)

```ts
abstract class Shape {
  constructor(
    public x: number,
    public y: number,
    public color: string
  ) {}
  abstract clone(): Shape;
}

class Rectangle extends Shape {
  constructor(
    x: number,
    y: number,
    color: string,
    public width: number,
    public height: number
  ) {
    super(x, y, color);
  }
  clone(): Shape {
    return new Rectangle(this.x, this.y, this.color, this.width, this.height);
  }
}

// Client—works with any cloneable shape without knowing concrete class
const shapesCopy = shapes.map((s) => s.clone());
```

## Pros / Cons

**Pros:** Alternative to inheritance for config presets; clone without coupling; reduce init duplication.

**Cons:** Cloning with circular references is tricky.

## Relations

- Prototype vs Factory Method: Prototype avoids inheritance; Factory Method requires init step
- Prototype + Command: save command copies for history
- Prototype + Composite/Decorator: clone complex structures
- Prototype vs Memento: Prototype simpler for straightforward objects

## References

- [Refactoring Guru](https://refactoring.guru/design-patterns/prototype)
- [TypeScript example](https://refactoring.guru/design-patterns/prototype/typescript/example)
