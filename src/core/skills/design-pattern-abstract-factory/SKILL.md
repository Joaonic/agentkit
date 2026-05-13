---
name: design-pattern-abstract-factory
description: Abstract Factory produces families of related objects without specifying concrete classes. Use when working with product families (e.g. UI themes, OS-specific components) or when client code must remain independent of how products are created.
---

# Abstract Factory

## Intent

Produces families of related objects without specifying their concrete classes. Ensures products from the same factory are compatible (e.g. Modern chair + Modern sofa, not Victorian chair + Modern sofa).

## Problem

- Need to create objects that match others of the same family (chair + sofa + table in same style)
- Do not want to change existing code when adding new product families or variants
- Product families have several variants (Modern, Victorian, ArtDeco, etc.)

## Solution

1. Declare interfaces for each product in the family (Chair, Sofa, CoffeeTable)
2. Declare Abstract Factory with creation methods for each product, returning abstract types
3. Each concrete factory (ModernFactory, VictorianFactory) creates products of one variant only
4. Client works via abstract interfaces; app selects factory at init based on config/environment

## When to Use

- Code works with various families of related products but should not depend on concrete classes
- Need to ensure products are compatible within a family
- Class with many Factory Methods blurs primary responsibility → extract to Abstract Factory

## Structure (TypeScript)

```ts
interface GUIFactory {
  createButton(): Button;
  createCheckbox(): Checkbox;
}

class WinFactory implements GUIFactory {
  createButton() {
    return new WinButton();
  }
  createCheckbox() {
    return new WinCheckbox();
  }
}

class MacFactory implements GUIFactory {
  createButton() {
    return new MacButton();
  }
  createCheckbox() {
    return new MacCheckbox();
  }
}

// Client receives factory at init; uses it for all creation
class Application {
  constructor(private factory: GUIFactory) {}
  createUI() {
    const button = this.factory.createButton();
    button.paint();
  }
}
```

## Pros / Cons

**Pros:** OCP (new variants without breaking clients); SRP (creation isolated); compatible products; loose coupling.

**Cons:** Many new interfaces and classes; may overcomplicate if product families are simple.

## Relations

- Often evolves from Factory Method when many product types appear
- Abstract Factory ≠ Builder: AF returns product immediately; Builder has construction steps
- Can use Prototype to compose creation methods
- AF + Bridge: encapsulate which abstractions work with which implementations

## References

- [Refactoring Guru](https://refactoring.guru/design-patterns/abstract-factory)
- [TypeScript example](https://refactoring.guru/design-patterns/abstract-factory/typescript/example)
