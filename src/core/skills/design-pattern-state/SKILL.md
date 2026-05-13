---
name: design-pattern-state
description: State lets object alter behavior when internal state changes. Use when many states, state-specific code changes often, or replacing giant conditionals.
---

# State

## Intent

Let object alter behavior when internal state changes. Appears as if object changed its class. Related to Finite-State Machine.

## Problem

- Object in one of several states; behavior differs per state
- Conditionals in every method based on state
- Adding states/transitions multiplies conditionals; hard to maintain

## Solution

1. Create class per state; extract state-specific behavior
2. **Context** holds reference to current state object
3. Context delegates state-related work to state object
4. State object can trigger transitions (replace state in context)
5. All state classes share interface

Difference from Strategy: states know each other and initiate transitions.

## When to Use

- Object behaves differently by state; many states; code changes often
- Class full of conditionals altering behavior by field values
- Duplicate code across similar states/transitions

## Structure (TypeScript)

```ts
abstract class State {
  constructor(protected player: AudioPlayer) {}
  abstract clickLock(): void;
  abstract clickPlay(): void;
}

class LockedState extends State {
  clickLock() {
    this.player.changeState(
      this.player.playing ? new PlayingState(this.player) : new ReadyState(this.player)
    );
  }
  clickPlay() {
    /* locked */
  }
}

class ReadyState extends State {
  clickLock() {
    this.player.changeState(new LockedState(this.player));
  }
  clickPlay() {
    this.player.startPlayback();
    this.player.changeState(new PlayingState(this.player));
  }
}

class AudioPlayer {
  state: State;
  constructor() {
    this.state = new ReadyState(this);
  }
  changeState(s: State) {
    this.state = s;
  }
  clickLock() {
    this.state.clickLock();
  }
}
```

## Pros / Cons

**Pros:** Remove bulky conditionals; OCP; SRP.

**Cons:** Overkill for few states or rare changes.

## Relations

- State extends Strategy; states can alter context; strategies independent
- Project: `xstate-conversation-machine` for conversation state

## References

- [Refactoring Guru](https://refactoring.guru/design-patterns/state)
- [TypeScript example](https://refactoring.guru/design-patterns/state/typescript/example)
