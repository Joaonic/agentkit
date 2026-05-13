---
name: design-pattern-factory-method
description: Factory Method provides an interface for creating objects in a superclass, but lets subclasses alter the type created. Use when exact types are unknown at compile time, extending libraries/frameworks, or reusing objects (pool) instead of rebuilding.
---

# Factory Method

Also known as: Virtual Constructor

## Intent

Provides an interface for creating objects in a superclass; subclasses alter the type of objects created. Product creation is **not** the creator's primary responsibility—the creator has core business logic that depends on products.

## Problem

- Most code coupled to concrete classes (e.g. Truck); adding Ship requires changes everywhere
- Conditionals everywhere to switch behavior by product type

## Solution

1. Replace direct `new` with calls to a factory method
2. Override factory method in subclasses to return different product types
3. All products implement the same interface
4. Client code works with abstract products; doesn't care about concrete type

Factory method can also return cached/pooled objects, not just new instances.

## When to Use

- Don't know beforehand exact types and dependencies
- Want to let library/framework users extend internal components
- Save resources by reusing objects (pool) instead of rebuilding

## Structure (TypeScript)

```ts
abstract class Dialog {
  abstract createButton(): Button;

  render() {
    const okButton = this.createButton();
    okButton.onClick(() => this.close());
    okButton.render();
  }
}

class WindowsDialog extends Dialog {
  createButton(): Button {
    return new WindowsButton();
  }
}

class WebDialog extends Dialog {
  createButton(): Button {
    return new HTMLButton();
  }
}

// App selects creator at init
const config = readConfig();
const dialog = config.OS === 'Windows' ? new WindowsDialog() : new WebDialog();
dialog.render();
```

## Pros / Cons

**Pros:** OCP; SRP; avoid coupling creator to concrete products.

**Cons:** Many subclasses; best when introducing into existing creator hierarchy.

## Relations

- Often evolves into Abstract Factory, Prototype, or Builder
- Abstract Factory classes often use Factory Methods
- Factory Method is a specialization of Template Method

## References

- [Refactoring Guru](https://refactoring.guru/design-patterns/factory-method)
- [TypeScript example](https://refactoring.guru/design-patterns/factory-method/typescript/example)
