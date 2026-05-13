---
name: design-pattern-composite
description: Composite composes objects into trees and treats individual objects and compositions uniformly. Use when core model is tree-like (products in boxes, UI hierarchy, file system).
---

# Composite

Also known as: Object Tree

## Intent

Compose objects into tree structures; work with them as if they were individual objects. Client treats leaves and containers uniformly.

## Problem

- Products and Boxes; boxes contain products and smaller boxes
- Need total price: must recurse through nesting without knowing structure upfront
- Direct approach couples to concrete classes and nesting depth

## Solution

1. Common interface for leaves and containers with method(s) meaningful for both (e.g. `getPrice()`)
2. Leaf returns its value
3. Container delegates to children, aggregates result
4. Client invokes same method on any component; tree handles recursion

## When to Use

- Tree-like object structure
- Client should treat simple and complex elements uniformly
- Recursive operations (render, validate, sum)

## Structure (TypeScript)

```ts
interface Graphic {
  move(x: number, y: number): void;
  draw(): void;
}

class Dot implements Graphic {
  constructor(
    public x: number,
    public y: number
  ) {}
  move(dx: number, dy: number) {
    this.x += dx;
    this.y += dy;
  }
  draw() {
    /* draw dot */
  }
}

class CompoundGraphic implements Graphic {
  private children: Graphic[] = [];
  add(c: Graphic) {
    this.children.push(c);
  }
  move(dx: number, dy: number) {
    this.children.forEach((c) => c.move(dx, dy));
  }
  draw() {
    this.children.forEach((c) => c.draw());
  }
}
```

## Pros / Cons

**Pros:** OCP; convenient tree handling; polymorphism + recursion.

**Cons:** Hard to provide common interface if classes differ greatly.

## Relations

- Builder for complex Composite trees
- Chain of Responsibility + Composite: request bubbles up
- Iterator for traversal; Visitor for operations

## References

- [Refactoring Guru](https://refactoring.guru/design-patterns/composite)
- [TypeScript example](https://refactoring.guru/design-patterns/composite/typescript/example)
