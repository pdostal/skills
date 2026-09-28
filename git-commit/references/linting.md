# Language-specific linting before commit

## Perl

Projects with a `.perltidyrc`:

```bash
perltidy --profile=.perltidyrc <file> -o /tmp/tidy.pm && diff <file> /tmp/tidy.pm || cp /tmp/tidy.pm <file>
```

Stage any linter-induced changes before committing.

## Python

Prefer `ruff` for linting/formatting, run via `uv`:

```bash
uvx ruff check --fix .
uvx ruff format .
```

If the project already has `pytest` configured (`pytest.ini`, a
`[tool.pytest.ini_options]` table, or a wired-up `tests/` suite), run it as-is
instead of replacing it: `uv run pytest`.
