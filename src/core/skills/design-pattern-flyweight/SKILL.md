---
name: design-pattern-flyweight
description: Flyweight shares intrinsic (immutable) state between many objects to save RAM. Use when huge number of similar objects and duplicate state can be extracted and shared.
---

# Flyweight

Also known as: Cache

## Intent

Fit more objects into RAM by sharing common state between multiple objects instead of keeping all data in each.

## Problem

- Many similar objects (e.g. particles, tree sprites); each has heavy duplicate data (color, texture)
- RAM exhausted when spawning many

## Solution

1. **Intrinsic state** (shared, immutable): color, texture—stays in flyweight
2. **Extrinsic state** (context-specific): coordinates, velocity—passed to methods or stored in context
3. Flyweight factory: cache by intrinsic state; return existing or create new
4. Client/Context stores extrinsic state; flyweight is template configured at call time

Flyweights must be immutable.

## When to Use

- Huge number of objects that barely fit in RAM
- Duplicate state can be extracted and shared
- Application spawns many similar objects

## Structure (TypeScript)

```ts
class TreeType {
  constructor(
    public name: string,
    public color: string,
    public texture: string
  ) {}
  draw(canvas: Canvas, x: number, y: number) {
    /* draw at x,y */
  }
}

class TreeFactory {
  private static types = new Map<string, TreeType>();
  static getTreeType(name: string, color: string, texture: string): TreeType {
    const key = `${name}-${color}-${texture}`;
    if (!this.types.has(key)) {
      this.types.set(key, new TreeType(name, color, texture));
    }
    return this.types.get(key)!;
  }
}

class Tree {
  constructor(
    public x: number,
    public y: number,
    private type: TreeType
  ) {}
  draw(canvas: Canvas) {
    this.type.draw(canvas, this.x, this.y);
  }
}
```

## Pros / Cons

**Pros:** Save RAM with many similar objects.

**Cons:** More complex; may trade RAM for CPU if extrinsic state recalculated; team may find separation confusing.

## Relations

- Flyweight vs Singleton: Flyweight immutable, many instances (different intrinsic); Singleton mutable, one instance
- Use Flyweight for shared leaf nodes in Composite trees

## References

- [Refactoring Guru](https://refactoring.guru/design-patterns/flyweight)
- [TypeScript example](https://refactoring.guru/design-patterns/flyweight/typescript/example)
