---
name: design-pattern-builder
description: Builder constructs complex objects step by step. Use when objects have many optional parameters (telescoping constructors), need different representations (stone vs wood house), or construction involves similar steps with varying details.
---

# Builder

## Intent

Construct complex objects step by step. Produce different types and representations using the same construction code. Builder does not allow access to the product while it is being built.

## Problem

- Complex object with many optional parameters → huge constructor or many overloads
- Subclass per configuration → explosion of classes
- Construction logic scattered across client code

## Solution

1. Extract construction into builder objects with methods for each step (buildWalls, buildDoor, etc.)
2. Client calls only the steps needed for desired configuration
3. Different builders implement same steps differently (WoodBuilder, StoneBuilder)
4. **Director** (optional): encapsulates common construction sequences; client can use diretor or call builder directly
5. Result fetched from builder, not diretor (products may not share interface)

## When to Use

- Telescoping constructor (many optional params)
- Different representations of a product with similar construction steps
- Build Composite trees or complex objects step-by-step
- Defer steps, run recursively; hide incomplete product during construction

## Structure (TypeScript)

```ts
interface Builder {
  reset(): void;
  setSeats(n: number): void;
  setEngine(engine: Engine): void;
  setGPS(enabled: boolean): void;
}

class CarBuilder implements Builder {
  private car!: Car;
  reset() {
    this.car = new Car();
  }
  setSeats(n: number) {
    /* ... */
  }
  setEngine(e: Engine) {
    /* ... */
  }
  setGPS(b: boolean) {
    /* ... */
  }
  getProduct(): Car {
    const p = this.car;
    this.reset();
    return p;
  }
}

class Director {
  constructSportsCar(builder: Builder) {
    builder.reset();
    builder.setSeats(2);
    builder.setEngine(new SportEngine());
    builder.setGPS(true);
  }
}

const diretor = new Director();
const builder = new CarBuilder();
diretor.constructSportsCar(builder);
const car = builder.getProduct();
```

## Pros / Cons

**Pros:** SRP (construction isolated); reuse construction code; step-by-step; defer/recursive steps.

**Cons:** More classes; complexity increases.

## Relations

- Builder vs Abstract Factory: Builder focuses on construction steps; AF returns product immediately
- Builder for complex Composite trees (recursive steps)
- Builder + Bridge: Director = abstraction, builders = implementations

## References

- [Refactoring Guru](https://refactoring.guru/design-patterns/builder)
- [TypeScript example](https://refactoring.guru/design-patterns/builder/typescript/example)
