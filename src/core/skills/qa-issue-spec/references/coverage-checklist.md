# Coverage Checklist

Use this to pressure-test scenario completeness. Include only relevant items.

## Input and Validation

- empty input
- missing field
- invalid format
- min/max boundary
- duplicate submission

## State and Persistence

- refresh after success/failure
- retry after transient failure
- idempotent re-submit
- rollback or cancellation

## Permissions and Isolation

- authorized role
- unauthorized role
- hidden vs disabled control
- tenant/account isolation

## Integration and Resilience

- downstream timeout
- downstream 4xx/5xx
- webhook/event side effects
- duplicate event delivery

## UX and Accessibility

- loading/empty/error states
- success feedback clarity
- keyboard navigation
- screen reader labels
- responsive behavior

## Data Integrity and Regression

- duplicate/conflicting updates
- wrong mapping/serialization
- sibling flow regressions
- filters/sorting/pagination regressions
