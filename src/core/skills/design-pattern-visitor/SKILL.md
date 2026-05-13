---
name: design-pattern-visitor
description: Visitor adds operations to object structure without changing classes. Uses double dispatch. Use when structure stable but operations vary, or behavior only for some element classes.
---

# Visitor

## Intent

Separate algorithms from objects they operate on. Add operations without changing element classes.

## Problem

- Need new operation on all elements (e.g. XML export)
- Can't alter element classes (production, risk)
- Export code doesn't belong in element classes
- Future formats = more changes to elements

## Solution

1. Put new behavior in **Visitor** class
2. Visitor has method per element type (visitDot, visitCircle, ...)
3. **Element** has `accept(visitor)`: calls visitor.visitX(this)
4. **Double dispatch**: element's accept selects correct visitor method
5. Client: `element.accept(visitor)` for each element

Adding new behavior = new visitor class; elements unchanged.

## When to Use

- Operation on all elements of complex structure (e.g. tree)
- Clean up auxiliary behaviors from main classes
- Behavior makes sense only for some element classes

## Structure (TypeScript)

```ts
interface Shape {
  accept(v: Visitor): void;
}

interface Visitor {
  visitDot(d: Dot): void;
  visitCircle(c: Circle): void;
}

class Dot implements Shape {
  accept(v: Visitor) {
    v.visitDot(this);
  }
}

class Circle implements Shape {
  accept(v: Visitor) {
    v.visitCircle(this);
  }
}

class XMLExportVisitor implements Visitor {
  visitDot(d: Dot) {
    /* export dot */
  }
  visitCircle(c: Circle) {
    /* export circle */
  }
}

// Client
const exportVisitor = new XMLExportVisitor();
shapes.forEach((s) => s.accept(exportVisitor));
```

## Pros / Cons

**Pros:** Accumulate info while traversing; SRP; OCP (new visitors without changing elements).

**Cons:** May need public access to private members; must update all visitors when element hierarchy changes.

## Relations

- Visitor ≈ powerful Command (executes over various object classes)
- Visitor for operations over entire Composite tree
- Visitor + Iterator to traverse and operate

## References

- [Refactoring Guru](https://refactoring.guru/design-patterns/visitor)
- [TypeScript example](https://refactoring.guru/design-patterns/visitor/typescript/example)
