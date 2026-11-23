# Changelog

## 0.4.0 - 2026-11-23

- Cache parameterized queries as named prepared statements per connection, so repeated queries skip parsing and can use a generic plan. A stale statement is prepared again and retried once. `set_statement_cache(false)` turns it off for transaction-mode poolers, and `cached_statements()` reports the count.

## 0.3.1 - 2026-11-22

- Report a plain "the server did not answer as PostgreSQL" error when the port runs something else, instead of a message size error.

## 0.3.0 - 2026-11-21

- Ported to Raven 3 syntax; requires Raven 3.0.1 or newer.

## 0.2.0 - 2026-07-15

- Guarantee complete socket writes for startup and query messages.
- Validate backend message sizes and fixed-format protocol messages.
- Reject invalid NUL-containing startup, password, and query values.
- Reject excess bind parameters before encoding the query.
- Validate result-set ordering and row column counts.
- Drain unsupported multiple-result and COPY exchanges so connections remain reusable.
- Expand protocol and Docker end-to-end recovery coverage.
- Test PostgreSQL 16 and 17 with Raven 2.26.1 in CI.

## 0.1.0 - 2026-06-29

- Initial release.
