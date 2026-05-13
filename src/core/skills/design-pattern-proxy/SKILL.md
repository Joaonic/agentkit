---
name: design-pattern-proxy
description: Proxy provides substitute for another object; controls access. Use for lazy init, access control, caching, remote proxy, logging. Same interface as service; manages service lifecycle.
---

# Proxy

## Intent

Provide substitute or placeholder for another object. Proxy controls access—perform something before or after request reaches original.

## Problem

- Heavy object; need only sometimes. Lazy init—but duplication if done in each client
- Class may be from closed 3rd-party library

## Solution

Create proxy with same interface as service. Proxy receives request, does extra work (lazy init, cache, log, access check), delegates to real service. Usually manages full lifecycle of service.

## When to Use

- **Lazy init:** create only when needed
- **Access control:** only certain clients
- **Remote proxy:** service on remote server
- **Logging:** history of requests
- **Caching:** cache results, manage lifecycle
- **Smart reference:** dismiss when no clients

## Structure (TypeScript)

```ts
interface ThirdPartyYouTubeLib {
  listVideos(): string[];
  getVideoInfo(id: string): string;
  downloadVideo(id: string): void;
}

class YouTubeService implements ThirdPartyYouTubeLib {
  listVideos() {
    /* API */
  }
  getVideoInfo(id: string) {
    /* API */
  }
  downloadVideo(id: string) {
    /* API */
  }
}

class CachedYouTubeProxy implements ThirdPartyYouTubeLib {
  private listCache: string[] | null = null;
  private videoCache = new Map<string, string>();

  constructor(private service: ThirdPartyYouTubeLib) {}

  listVideos() {
    if (!this.listCache) this.listCache = this.service.listVideos();
    return this.listCache;
  }
  getVideoInfo(id: string) {
    if (!this.videoCache.has(id)) this.videoCache.set(id, this.service.getVideoInfo(id));
    return this.videoCache.get(id)!;
  }
  downloadVideo(id: string) {
    this.service.downloadVideo(id);
  }
}

const manager = new YouTubeManager(new CachedYouTubeProxy(new YouTubeService()));
```

## Pros / Cons

**Pros:** OCP; works if service not ready; manage lifecycle; control without client knowing.

**Cons:** Response delay; more classes.

## Relations

- Proxy vs Adapter: Proxy = same interface; Adapter = different interface
- Proxy vs Decorator: Proxy manages lifecycle; Decorator composition by client

## References

- [Refactoring Guru](https://refactoring.guru/design-patterns/proxy)
- [TypeScript example](https://refactoring.guru/design-patterns/proxy/typescript/example)
