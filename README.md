# raven-postgres

A PostgreSQL client for the [Raven](https://github.com/martian56/raven)
programming language, written in pure Raven. It speaks the PostgreSQL v3 wire
protocol directly over `std/net`, with no native dependencies.

> Status: **v0.1.0**, an early but working release. It does the startup
> handshake, authentication, the simple query protocol, and parameterized
> queries (text results). See [Roadmap](#roadmap) for what is next.

## Features

- Connect and authenticate (trust and cleartext password).
- Run any SQL with `query` (rows + columns) or `execute` (affected-row count).
- **Parameterized queries** (`query_params` / `execute_params`) with `$1, $2, ...`
  placeholders, values bound over the wire and never interpolated into the SQL.
- Column names, row values, and SQL `NULL` handling.
- Server errors surfaced as a Raven `Result` `Err` with the PostgreSQL
  severity, SQLSTATE code, and message; the connection stays usable afterward.

## Install

In your `rv.toml`:

```toml
[dependencies]
"github.com/martian56/raven-postgres" = "v0.1.0"
```

## Quick start

```raven
import std/io { println }
import "github.com/martian56/raven-postgres" { connect }

fun main() {
    match connect("127.0.0.1", 5432, "user", "pass", "mydb") {
        Ok(conn) -> {
            let _ = conn.execute("CREATE TABLE IF NOT EXISTS pets (name TEXT, age INT)")
            let _ = conn.execute("INSERT INTO pets VALUES ('rex', 4)")

            match conn.query("SELECT name, age FROM pets") {
                Ok(res) -> {
                    for row in res.rows {
                        println("${row.get(0)} is ${row.get(1)}")
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

See [`examples/basic.rv`](examples/basic.rv) for a fuller walkthrough.

## API

```raven
connect(host: String, port: Int, user: String, password: String, database: String) -> Result<Connection, Error>
```

`Connection` methods:

- `query(sql: String) -> Result<QueryResult, Error>` runs a statement and
  collects its result. A `SELECT` fills `columns` and `rows`; a write fills
  `affected`.
- `query_params(sql: String, params: List<String>) -> Result<QueryResult, Error>`
  runs a statement with `$1, $2, ...` placeholders, binding each value over the
  wire. Use this for any user-supplied value: the value is sent as data, not
  spliced into the SQL text. PostgreSQL infers parameter types from context
  (column types or casts such as `$1::int`).
- `execute(sql: String) -> Result<Int, Error>` and
  `execute_params(sql: String, params: List<String>) -> Result<Int, Error>` run
  a statement and return only the affected-row count.
- `close()` sends Terminate and closes the socket.

```raven
// Safe: the value is bound, never concatenated into SQL.
let _ = conn.execute_params("INSERT INTO users (name) VALUES ($1)", [userName])
let res = conn.query_params("SELECT id FROM users WHERE name = $1", [userName])?
```

`QueryResult`: `columns: List<String>`, `rows: List<Row>`, `affected: Int`,
and `row_count() -> Int`.

`Row`: `get(i: Int) -> String` (the column's text value, empty when NULL) and
`is_null(i: Int) -> Bool`.

All values come back as text (PostgreSQL's text format); convert as needed with
the stdlib.

## Authentication

The server's `pg_hba.conf` decides the method. Supported today: `trust` (no
password) and `password` (cleartext). `md5` and `scram-sha-256` are not
implemented yet and return a clear error, they need MD5 / SHA-256 in the Raven
runtime. For local development, configure the server with `password` auth.

## Running the tests

The client is developed against a disposable PostgreSQL in Docker. Start one on
a non-default port so it does not clash with a local server:

```bash
docker run -d --name raven-pg-test \
  -e POSTGRES_USER=raven -e POSTGRES_PASSWORD=ravenpw -e POSTGRES_DB=ravendb \
  -e POSTGRES_HOST_AUTH_METHOD=password \
  -p 55432:5432 postgres:16-alpine
```

Then point `examples/basic.rv` (or your own program) at `127.0.0.1:55432` with
user `raven`, password `ravenpw`, database `ravendb`.

## Roadmap

- `md5` and `scram-sha-256` authentication.
- NULL and typed parameter binding (today every bound value is a non-null string).
- TLS (`sslmode`) using Raven's `std/tls` `upgrade`.
- Typed value decoding (integers, booleans, timestamps) beyond text.
- Connection pooling helpers.

## License

MIT. See [LICENSE](LICENSE).
