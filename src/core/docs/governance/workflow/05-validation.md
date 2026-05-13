# 05 - Validation

Use `posttask` as mandatory completion gate.

Expected baseline by stack:
- Java: `./mvnw test`, `./mvnw verify`
- Bun: `bun run type-check`, `bun test`, `bun run build`
- Web: `yarn lint`, `yarn build`, `yarn test` (if exists)

Rules:
- report each command with pass/fail/n-a
- failed mandatory checks block completion
- cancelled CI must be diagnosed to root failure, not ignored
