---
name: design-pattern-strategy
description: Strategy defines family of algorithms, encapsulates each, makes them interchangeable. Use when several variants of algorithm, switch at runtime, or replace conditional.
---

# Strategy

## Intent

Define family of algorithms, put each in separate class, make objects interchangeable. Context delegates to strategy.

## Problem

- Same task, different algorithms (routing: car, foot, transit)
- Each new algorithm bloats main class
- Changes to one affect others; merge conflicts

## Solution

1. Extract each algorithm into strategy class
2. Context has reference to strategy
3. Context delegates work to strategy; doesn't select it
4. Client passes desired strategy to context
5. Context works with strategies via common interface

## When to Use

- Use different algorithm variants in object; switch at runtime
- Many similar classes differing only in one behavior
- Isolate algorithm details from business logic
- Massive conditional switching algorithm variants

## Structure (TypeScript)

```ts
interface Strategy {
  execute(a: number, b: number): number;
}

class AddStrategy implements Strategy {
  execute(a: number, b: number) {
    return a + b;
  }
}

class MultiplyStrategy implements Strategy {
  execute(a: number, b: number) {
    return a * b;
  }
}

class Context {
  constructor(private strategy: Strategy) {}
  setStrategy(s: Strategy) {
    this.strategy = s;
  }
  executeStrategy(a: number, b: number) {
    return this.strategy.execute(a, b);
  }
}

const ctx = new Context(new AddStrategy());
ctx.executeStrategy(3, 4); // 7
ctx.setStrategy(new MultiplyStrategy());
ctx.executeStrategy(3, 4); // 12
```

## Pros / Cons

**Pros:** OCP; composition over inheritance; isolate algorithm; swap at runtime.

**Cons:** May overcomplicate if few algorithms, rarely change; clients must choose strategy; modern langs can use functions instead of classes.

## Relations

- Strategy vs Command: Strategy = swap algorithm; Command = operation as object (queue, undo)
- Decorator changes skin; Strategy changes guts
- Template Method (inheritance) vs Strategy (composition, runtime)

## References

- [Refactoring Guru](https://refactoring.guru/design-patterns/strategy)
- [TypeScript example](https://refactoring.guru/design-patterns/strategy/typescript/example)
