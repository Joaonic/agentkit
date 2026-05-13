---
name: design-pattern-facade
description: Facade provides simplified interface to complex subsystem. Use when integrating with complex library (only need subset), structuring subsystem into layers, or isolating client from many moving parts.
---

# Facade

## Intent

Provides simplified interface to library, framework, or complex set of classes. Limited functionality compared to direct use, but only what clients need.

## Problem

- Must initialize many objects, track dependencies, call in correct order
- Business logic tightly coupled to 3rd-party implementation details
- Hard to comprehend and maintain

## Solution

Facade class encapsulates subsystem, exposes few methods. Client calls facade; facade orchestrates subsystem. Subsystem unaware of facade.

Example: video conversion—many codecs, readers, mixers; facade exposes `convert(filename, format)`.

## When to Use

- Limited but straightforward interface to complex subsystem
- Structure subsystem into layers; define entry point per layer
- Isolate client from complexity; reduce coupling

## Structure (TypeScript)

```ts
class VideoConverter {
  convert(filename: string, format: string): File {
    const file = new VideoFile(filename);
    const sourceCodec = new CodecFactory().extract(file);
    const destCodec = format === 'mp4' ? new MPEG4Codec() : new OggCodec();
    const buffer = BitrateReader.read(filename, sourceCodec);
    const result = BitrateReader.convert(buffer, destCodec);
    return new File(new AudioMixer().fix(result));
  }
}

class Application {
  main() {
    const converter = new VideoConverter();
    const mp4 = converter.convert('video.ogg', 'mp4');
  }
}
```

## Pros / Cons

**Pros:** Isolate code from subsystem complexity.

**Cons:** Facade can become god object coupled to many classes.

## Relations

- Facade vs Adapter: Facade = new interface; Adapter = make existing usable. Facade works with subsystem; Adapter wraps one object
- Facade can become Singleton

## References

- [Refactoring Guru](https://refactoring.guru/design-patterns/facade)
- [TypeScript example](https://refactoring.guru/design-patterns/facade/typescript/example)
