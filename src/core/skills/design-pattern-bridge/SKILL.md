---
name: design-pattern-bridge
description: Bridge splits abstraction from implementation so they can vary independently. Use when extending in orthogonal dimensions causes subclass explosion (e.g. Shape × Color → RedCircle, BlueCircle, RedSquare...).
---

# Bridge

## Intent

Split large class or set of related classes into two hierarchies—abstraction and implementation—developed independently. Switch from inheritance to composition.

## Problem

- Shape + subclasses (Circle, Square); add Color → need RedCircle, BlueCircle, RedSquare, BlueSquare
- Each new shape or color multiplies combinations exponentially
- Same for GUI × OS API, etc.

## Solution

Extract one dimension into separate class hierarchy. Original holds reference to it and delegates.

- **Abstraction** (high-level): GUI, control logic; delegates to implementation
- **Implementation** (platform): OS API, renderer, DB driver

Shape holds reference to Color; adding new color doesn't touch shapes.

## When to Use

- Monolithic class with several variants of functionality
- Extend class in several orthogonal dimensions
- Switch implementations at runtime

## Structure (TypeScript)

```ts
interface Device {
  isEnabled(): boolean;
  enable(): void;
  disable(): void;
  getVolume(): number;
  setVolume(p: number): void;
}

class RemoteControl {
  constructor(protected device: Device) {}
  togglePower() {
    if (this.device.isEnabled()) this.device.disable();
    else this.device.enable();
  }
  volumeUp() {
    this.device.setVolume(this.device.getVolume() + 10);
  }
}

class AdvancedRemote extends RemoteControl {
  mute() {
    this.device.setVolume(0);
  }
}

class Tv implements Device {
  /* ... */
}
class Radio implements Device {
  /* ... */
}

const remote = new AdvancedRemote(new Radio());
```

## Pros / Cons

**Pros:** SRP; OCP; client works with abstractions; platform-independent code.

**Cons:** Can overcomplicate highly cohesive classes.

## Relations

- Bridge vs Adapter: Bridge up-front; Adapter for existing incompatible code
- Bridge + Abstract Factory: encapsulate which abstractions work with which implementations

## References

- [Refactoring Guru](https://refactoring.guru/design-patterns/bridge)
- [TypeScript example](https://refactoring.guru/design-patterns/bridge/typescript/example)
