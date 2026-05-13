---
name: design-pattern-command
description: Command turns request into object with all info. Enables queuing, undo, deferred execution. Use for action queues (BullMQ), undo/redo, decoupling invoker from executor.
---

# Command

Also known as: Action, Transaction

## Intent

Turn request into stand-alone object containing all request information. Enables passing as argument, delay/queue execution, undoable operations.

## Problem

- GUI buttons, menus, shortcuts trigger operations; each needs different code
- Subclass per operation → explosion
- Same operation from multiple places → duplication or coupling

## Solution

1. Extract request into Command class with `execute()`
2. Command holds receiver reference and params (or fetches them)
3. Invoker stores Command, calls `execute()` on interaction
4. Same Command can be bound to button, menu, shortcut
5. For undo: save state before execute; `undo()` restores

## When to Use

- Parameterize objects with operations
- Queue, schedule, or execute remotely
- Implement undo/redo

## Structure (TypeScript)

```ts
interface Command {
  execute(): boolean; // true if state changed (for undo history)
}

abstract class AbstractCommand {
  constructor(
    protected app: Application,
    protected editor: Editor
  ) {}
  protected backup = '';
  saveBackup() {
    this.backup = this.editor.text;
  }
  undo() {
    this.editor.text = this.backup;
  }
  abstract execute(): boolean;
}

class CopyCommand extends AbstractCommand {
  execute() {
    this.app.clipboard = this.editor.getSelection();
    return false;
  }
}

class CutCommand extends AbstractCommand {
  execute() {
    this.saveBackup();
    this.app.clipboard = this.editor.getSelection();
    this.editor.deleteSelection();
    return true;
  }
}

// Invoker
class Application {
  executeCommand(cmd: Command) {
    if (cmd.execute()) this.history.push(cmd);
  }
  undo() {
    this.history.pop()?.undo();
  }
}
```

## Pros / Cons

**Pros:** Assemble commands; deferred execution; undo/redo; OCP; SRP.

**Cons:** Extra layer between senders and receivers.

## Relations

- Command + Memento for undo
- Command vs Strategy: Command = operation as object (queue, history); Strategy = swap algorithm
- BullMQ jobs ≈ Commands (serializable, queued)

## References

- [Refactoring Guru](https://refactoring.guru/design-patterns/command)
- [TypeScript example](https://refactoring.guru/design-patterns/command/typescript/example)
