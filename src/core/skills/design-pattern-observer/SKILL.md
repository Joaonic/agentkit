---
name: design-pattern-observer
description: Observer defines subscription to notify multiple objects of events. Use when one object changes and others must react, set of observers unknown or dynamic.
---

# Observer

Also known as: Event-Subscriber, Listener

## Intent

Define subscription mechanism to notify multiple objects about any events. Publisher + subscribers; dynamic subscribe/unsubscribe.

## Problem

- Customer wants to know when product arrives; Store must notify
- Polling wastes time; broadcast to all wastes resources (wrong recipients)

## Solution

1. **Publisher**: array of subscribers + subscribe/unsubscribe + notify
2. **Subscriber interface**: e.g. `update(data)`
3. On event, publisher iterates subscribers, calls update
4. Publisher communicates only via interface
5. Subscription list is dynamic

## When to Use

- Changes to one object require changing others; set unknown or dynamic
- Some objects observe others for limited time or specific cases

## Structure (TypeScript)

```ts
class EventManager {
  private listeners = new Map<string, Function[]>();
  subscribe(eventType: string, listener: Function) {
    const list = this.listeners.get(eventType) ?? [];
    list.push(listener);
    this.listeners.set(eventType, list);
  }
  notify(eventType: string, data: unknown) {
    (this.listeners.get(eventType) ?? []).forEach((fn) => fn(data));
  }
}

class Editor {
  events = new EventManager();
  openFile(path: string) {
    this.events.notify('open', path);
  }
}

const editor = new Editor();
editor.events.subscribe('open', (name) => console.log('Opened:', name));
```

## Pros / Cons

**Pros:** Relations at runtime; OCP.

**Cons:** Subscribers notified in random order.

## Relations

- Observer vs Mediator: Observer = dynamic one-way; Mediator = centralize mutual deps
- RxJS, EventEmitter implement Observer

## References

- [Refactoring Guru](https://refactoring.guru/design-patterns/observer)
- [TypeScript example](https://refactoring.guru/design-patterns/observer/typescript/example)
