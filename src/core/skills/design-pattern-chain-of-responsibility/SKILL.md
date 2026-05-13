---
name: design-pattern-chain-of-responsibility
description: Chain of Responsibility passes requests along handler chain. Each handler processes or forwards. Use when request types/sequences unknown, handlers order matters, or handler set changes at runtime.
---

# Chain of Responsibility

Also known as: CoR, Chain of Command

## Intent

Pass requests along chain of handlers. Each handler decides to process or pass to next. Decouples sender from receiver.

## Problem

- Sequential checks (auth, validation, rate limit, cache) scattered; changing one affects others
- Reusing checks for other components forces duplication
- Hard to maintain and extend

## Solution

1. Extract each check into handler class with single method
2. Link handlers: each has reference to next
3. Handler processes request and/or passes along
4. Handler can stop propagation
5. Client builds chain; request can start at any handler

Two approaches: (a) each handler does work then passes, or (b) first handler that can process it does and stops.

## When to Use

- Different request kinds, unknown types/sequences
- Several handlers must run in particular order
- Handler set and order change at runtime

## Structure (TypeScript)

```ts
interface Handler {
  setNext(h: Handler): Handler;
  handle(request: string): string | null;
}

abstract class AbstractHandler implements Handler {
  private next: Handler | null = null;
  setNext(h: Handler): Handler {
    this.next = h;
    return h;
  }
  handle(request: string): string | null {
    if (this.next) return this.next.handle(request);
    return null;
  }
}

class AuthHandler extends AbstractHandler {
  handle(request: string): string | null {
    if (request.includes('valid')) return super.handle(request);
    return null; // stop
  }
}
```

## Pros / Cons

**Pros:** OCP; SRP; control handling order.

**Cons:** Some requests may go unhandled.

## Relations

- CoR vs Observer/Mediator/Command: different ways to connect senders/receivers
- CoR + Composite: request bubbles up tree
- Handlers can be Commands; request can be Command

## References

- [Refactoring Guru](https://refactoring.guru/design-patterns/chain-of-responsibility)
- [TypeScript example](https://refactoring.guru/design-patterns/chain-of-responsibility/typescript/example)
