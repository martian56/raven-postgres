# Changelog

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
