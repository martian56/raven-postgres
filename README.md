# raven-postgres

[![CI](https://github.com/martian56/raven-postgres/actions/workflows/ci.yml/badge.svg)](https://github.com/martian56/raven-postgres/actions/workflows/ci.yml)

A pure-Raven PostgreSQL client for the
[Raven programming language](https://github.com/martian56/raven). It speaks
the PostgreSQL v3 frontend/backend protocol over `std/net`; applications do
not need `libpq`, a C compiler, or another native dependency.

> Status: **v0.1.0**, ready for initial use and tested end to end against
> PostgreSQL 16.9 and 17.5. See [Authentication and security](#authentication-and-security)
> before connecting outside a trusted development network.

## Features

- PostgreSQL v3 startup and authentication with `trust` or cleartext
  `password` rules.
- Simple-protocol SQL with column names, rows, affected-row counts, and
  `INSERT ... RETURNING` results.
- Extended-protocol parameters with `$1`, `$2`, ... placeholders; values are
  sent separately and never interpolated into SQL.
- Nullable parameters through `List<Option<String>>`.
- Correct distinction between SQL `NULL` and an empty string.
- UTF-8, large fields, large bound values, and hundreds of result rows.
- Transactions through ordinary SQL (`BEGIN`, `COMMIT`, and `ROLLBACK`).
- PostgreSQL severity and SQLSTATE values preserved in Raven `Error` results;
  connections remain reusable after statement and parameter errors.
- Partial TCP writes are completed, while malformed or oversized backend
  messages are rejected before allocation or parsing.
- Server version, backend process ID, health checks, and configurable socket
  timeouts.
- No native dependencies.

## Requirements

- Raven 2.26.1 or newer.
- A PostgreSQL `pg_hba.conf` rule using `trust` or `password` authentication.

The Docker environment included in this repository configures `password`
authentication automatically.

## Install

In `rv.toml`:

```toml
[dependencies]
"github.com/martian56/raven-postgres" = "v0.2.0"
```

## Quick start

```rust
import std/io { println }
import "github.com/martian56/raven-postgres" { connect }

fun main() {
    match connect("127.0.0.1", 5432, "raven", "ravenpw", "ravendb") {
        Ok(conn) -> {
            let _ = conn.execute(
                "CREATE TABLE IF NOT EXISTS pets (id BIGSERIAL PRIMARY KEY, name TEXT)",
            )

            // The value is bound by the extended protocol, not inserted into SQL.
            let _ = conn.execute_params("INSERT INTO pets (name) VALUES ($1)", ["O'Brien"])

            match conn.query("SELECT id, name FROM pets ORDER BY id") {
                Ok(result) -> {
                    for row in result.rows {
                        println("${row.get(0)}: ${row.get(1)}")
                    }
                },
                Err(e) -> println("query failed: ${e.message()}"),
            }
            conn.close()
        },
        Err(e) -> println("connect failed: ${e.message()}"),
    }
}
```

See [`examples/basic.rv`](examples/basic.rv) for a complete runnable example.

## API

### Connecting

```rust
connect(host, port, user, password, database) -> Result<Connection, Error>
connect_with_timeout(host, port, user, password, database, timeout_ms) -> Result<Connection, Error>
```

`connect` applies a 30-second read and write timeout. Use
`connect_with_timeout` to choose another value; a non-positive value restores
blocking socket I/O.

An open `Connection` exposes startup metadata:

```rust
println(conn.server_version)
println("backend ${conn.backend_pid}")
```

Always call `close()` when finished. It sends PostgreSQL's Terminate message
and releases the TCP stream. A failed handshake releases its stream
automatically.

### Queries and writes

- `query(sql) -> Result<QueryResult, Error>` sends a simple-protocol query and
  collects its response.
- `execute(sql) -> Result<Int, Error>` runs SQL and returns the affected-row
  count from the command tag.
- `query_params(sql, params)` and `execute_params(sql, params)` bind a
  `List<String>` through the extended query protocol.
- `query_optional_params(sql, params)` and `execute_optional_params(sql,
  params)` accept `List<Option<String>>`; `None` binds SQL `NULL`.
- `ping() -> Result<Bool, Error>` verifies the connection with `SELECT 1`.
- `set_timeout_ms(ms)` changes the read and write timeout for later commands.
- `close()` terminates the session.

### Parameters

Use `$1`, `$2`, and so on. Values travel in Bind messages and cannot change the
statement's SQL syntax:

```rust
let _ = conn.execute_params(
    "INSERT INTO users (name, age) VALUES ($1, $2)",
    [user_name, "42"],
)?

let nullable: List<Option<String>> = [Some(user_name), None]
let _ = conn.execute_optional_params(
    "INSERT INTO profiles (name, biography) VALUES ($1, $2)",
    nullable,
)?
```

Parameters use PostgreSQL's text format and have unspecified type OIDs, so the
server infers types from columns, operators, or explicit casts. Add casts where
the context is ambiguous:

```rust
let result = conn.query_params(
    "SELECT $1::integer + $2::integer",
    ["20", "22"],
)?
```

### Results

`QueryResult` contains:

- `columns: List<String>`: result column labels in order.
- `rows: List<Row>`: all returned rows.
- `affected: Int`: count parsed from command tags such as `INSERT 0 3`,
  `UPDATE 2`, or `DELETE 1`.
- `row_count() -> Int`: number of collected rows.

`Row.get(index)` returns the zero-based value in PostgreSQL's text format. A
SQL `NULL` returns `""`, so use `Row.is_null(index)` to distinguish it from an
actual empty string:

```rust
if row.is_null(2) {
    println("no value")
} else {
    println(row.get(2))
}
```

Integers, numerics, booleans, dates, times, and other values remain text.
Convert them with Raven's standard-library string methods when needed.

### Errors

PostgreSQL errors have kind `"postgres"` and preserve severity, SQLSTATE, and
the primary server message:

```text
ERROR 42P01: relation "missing" does not exist
```

After an extended-query error, the client drains messages through
`ReadyForQuery`, so the connection is synchronized for its next command.
Malformed row metadata and truncated row values return protocol errors instead
of indexing panics.

## Authentication and security

The server's `pg_hba.conf` selects authentication. This release supports:

- `trust`: no password challenge.
- `password`: PostgreSQL asks for the password as cleartext.

It does not yet support MD5 or SCRAM-SHA-256, and TLS is not implemented.
Cleartext password authentication must not be used over an untrusted network
without a separate secure tunnel. Unsupported authentication methods return a
clear error rather than sending a response with the wrong algorithm.

For a local development server, a host rule can use `password`:

```text
host all all 127.0.0.1/32 password
```

## Running tests

Protocol and parser tests do not need a server:

```bash
rvpm test
```

E2E tests are enabled by `RAVEN_POSTGRES_E2E=1`. The included scripts start a
fresh PostgreSQL 16 container, wait for its health check, run every test, and
remove the container and volume:

```powershell
./scripts/test-e2e.ps1
```

```bash
./scripts/test-e2e.sh
```

Set `KEEP_POSTGRES=1` with the shell script or pass `-Keep` to the PowerShell
script to leave the container running. `RAVEN_POSTGRES_PORT` changes the host
port from its default of `55432`.

The live suite covers authentication failures, CRUD, generated IDs, affected
rows, nullable and hostile parameters, transaction commit and rollback,
constraint and cast errors, recovery after errors, Unicode, scalar types,
multiple connections, 500-row results, a 262 KiB bound value, a 17 MB field,
COPY rejection, NUL validation, and multiple-result draining. CI runs it
against PostgreSQL 16.9 and 17.5.

## Compatibility and limits

- Tested against PostgreSQL 16.9 and 17.5.
- MD5, SCRAM-SHA-256, TLS, Unix-domain sockets, cancellation, notifications,
  connection pooling, and streaming cursors are not implemented yet.
- COPY streaming is rejected explicitly. COPY IN is aborted and COPY OUT is
  drained so the connection remains usable rather than hanging mid-copy.
- Parameters and results use text format; typed binary codecs are not exposed.
- `QueryResult` collects every row in memory.
- A backend message is limited to 256 MiB to bound memory use with malformed or
  hostile servers.
- The API models one row result set. If a query produces a second row result,
  raven-postgres drains it and returns a clear error rather than merging rows
  with incompatible metadata.

## License

MIT. See [LICENSE](LICENSE).
