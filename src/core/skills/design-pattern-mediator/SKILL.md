---
name: design-pattern-mediator
description: Mediator reduces dependencies by routing component communication through one object. Components don't know each other. Use when many components communicate directly and coupling is chaotic.
---

# Mediator

Also known as: Intermediary, Controller

## Intent

Reduce chaotic dependencies. Restrict direct communication; force collaboration only via mediator.

## Problem

- Form elements interact (checkbox reveals field, submit validates all)
- Each element knows about many others
- Reusing one element requires bringing all
- Changes ripple through many classes

## Solution

1. Components notify mediator instead of each other
2. Mediator knows all components; redirects to appropriate one
3. Components depend only on mediator (via interface)
4. Mediator encapsulates the relationship web

Dialog often acts as mediator for its controls.

## When to Use

- Hard to change classes due to tight coupling
- Can't reuse component (too dependent on others)
- Creating tons of subclasses to reuse basic behavior

## Structure (TypeScript)

```ts
interface Mediator {
  notify(sender: Component, event: string): void;
}

class AuthenticationDialog implements Mediator {
  constructor(
    private loginChk: Checkbox,
    private loginUser: Textbox,
    private okBtn: Button
  ) {}

  notify(sender: Component, event: string): void {
    if (sender === this.loginChk && event === 'check') {
      // Show/hide login vs registration
    }
    if (sender === this.okBtn && event === 'click') {
      // Validate and submit
    }
  }
}

class Component {
  constructor(protected dialog: Mediator) {}
  click() {
    this.dialog.notify(this, 'click');
  }
}
```

## Pros / Cons

**Pros:** Reuse components; reduce coupling; OCP; SRP.

**Cons:** Mediator can become God Object.

## Relations

- Mediator vs Facade: Mediator centralizes communication; Facade simplifies subsystem interface. Components don't talk in Mediator; subsystem objects do in Facade
- Mediator can use Observer (components subscribe to mediator events)

## References

- [Refactoring Guru](https://refactoring.guru/design-patterns/mediator)
- [TypeScript example](https://refactoring.guru/design-patterns/mediator/typescript/example)
