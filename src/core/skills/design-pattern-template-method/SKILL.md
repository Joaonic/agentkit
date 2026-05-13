---
name: design-pattern-template-method
description: Template Method defines algorithm skeleton in superclass; subclasses override steps. Use when many classes share algorithm with minor differences, or extend only certain steps.
---

# Template Method

## Intent

Define skeleton of algorithm in superclass; subclasses override specific steps without changing structure.

## Problem

- Similar algorithms in several classes with minor differences
- Algorithm change requires editing all
- Client has conditionals to pick processor

## Solution

1. Break algorithm into steps; each step = method
2. Template method in base class calls steps in order
3. Steps are abstract or have default impl
4. Subclasses implement abstract steps; may override optional
5. **Hooks**: optional empty methods before/after crucial steps

## When to Use

- Let clients extend only particular steps, not whole algorithm
- Several classes with almost identical algorithms

## Structure (TypeScript)

```ts
abstract class GameAI {
  turn() {
    this.collectResources();
    this.buildStructures();
    this.buildUnits();
    this.attack();
  }
  collectResources() {
    this.builtStructures.forEach((s) => s.collect());
  }
  abstract buildStructures(): void;
  abstract buildUnits(): void;
  attack() {
    const enemy = this.closestEnemy();
    if (!enemy) this.sendScouts(this.mapCenter);
    else this.sendWarriors(enemy.position);
  }
  abstract sendScouts(position: Point): void;
  abstract sendWarriors(position: Point): void;
}

class OrcsAI extends GameAI {
  buildStructures() {
    /* orc-specific */
  }
  buildUnits() {
    /* orc-specific */
  }
  sendScouts(p: Point) {
    /* ... */
  }
  sendWarriors(p: Point) {
    /* ... */
  }
}

class MonstersAI extends GameAI {
  collectResources() {
    /* no-op */
  }
  buildStructures() {
    /* no-op */
  }
  buildUnits() {
    /* no-op */
  }
  sendScouts(p: Point) {
    /* ... */
  }
  sendWarriors(p: Point) {
    /* ... */
  }
}
```

## Pros / Cons

**Pros:** Pull duplicate code to superclass; override only parts.

**Cons:** Harder to maintain as steps grow; may violate LSP if suppressing default step.

## Relations

- Factory Method is specialization of Template Method
- Template Method (inheritance, static) vs Strategy (composition, runtime)

## References

- [Refactoring Guru](https://refactoring.guru/design-patterns/template-method)
- [TypeScript example](https://refactoring.guru/design-patterns/template-method/typescript/example)
