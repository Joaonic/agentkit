---
name: design-pattern-adapter
description: Adapter makes incompatible interfaces work together by wrapping one object to match another. Use for legacy/3rd-party integration, hexgonal Ports/Adapters. Object adapter (composition) preferred over class adapter (inheritance).
---

# Adapter

Also known as: Wrapper

## Intent

Allows objects with incompatible interfaces to collaborate. Adapter converts interface of one object so another can understand it.

## Problem

- Need to use useful class (legacy, 3rd-party) but its interface doesn't match your code
- Can't change the library (closed source, existing deps)
- Client expects protocol A; service provides B

## Solution

**Object adapter** (preferred): Adapter implements client interface, wraps service object. Receives calls via client interface, translates to service format. Composition-based; works in TypeScript.

**Class adapter**: Adapter inherits from both client and service (requires multiple inheritance; not in TS).

Adapter wraps one object; client doesn't couple to adapter class as long as it uses the interface.

## When to Use

- Use existing class but interface is incompatible
- Reuse several subclasses that lack common functionality (add via adapter instead of duplicating in each)
- Hexagonal: Adapters implement Ports, wrapping Meta API, Shopify, etc.

## Structure (TypeScript)

```ts
// Client interface (Target / Port)
interface RoundPeg {
  getRadius(): number;
}

class RoundHole {
  constructor(private radius: number) {}
  fits(peg: RoundPeg): boolean {
    return this.radius >= peg.getRadius();
  }
}

// Incompatible service
class SquarePeg {
  constructor(private width: number) {}
  getWidth(): number {
    return this.width;
  }
}

// Adapter: SquarePeg → RoundPeg
class SquarePegAdapter implements RoundPeg {
  constructor(private peg: SquarePeg) {}
  getRadius(): number {
    return (this.peg.getWidth() * Math.sqrt(2)) / 2;
  }
}

const hole = new RoundHole(5);
const sqPeg = new SquarePeg(5);
hole.fits(new SquarePegAdapter(sqPeg)); // true
```

## Pros / Cons

**Pros:** OCP; SRP (conversion isolated); introduce new adapters without breaking clients.

**Cons:** More classes. Sometimes simpler to change service if possible.

## Relations

- Adapter vs Bridge: Bridge designed up-front; Adapter for existing incompatible code
- Adapter vs Decorator: Adapter changes interface; Decorator extends/same interface
- Adapter vs Proxy: Adapter = different interface; Proxy = same interface

## References

- [Refactoring Guru](https://refactoring.guru/design-patterns/adapter)
- [TypeScript example](https://refactoring.guru/design-patterns/adapter/typescript/example)
