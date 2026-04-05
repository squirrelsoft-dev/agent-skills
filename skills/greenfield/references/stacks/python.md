# Python Stack Reference

Loaded by SKILL.md Step 4 when `STACK` is `python`.

---

## Command Mapping

Resolve env vars using `PKG_MANAGER` as the column key:

| Env var | pip | poetry | uv |
|---|---|---|---|
| `INSTALL_CMD` | `pip install -r requirements.txt` | `poetry install` | `uv sync` |
| `BUILD_CMD` | `python -m build` | `poetry build` | `uv build` |
| `TEST_CMD` | `python -m pytest` | `poetry run pytest` | `uv run pytest` |
| `LINT_CMD` | `ruff check .` | `poetry run ruff check .` | `uv run ruff check .` |

> **Note:** For pip, if `pyproject.toml` exists without `requirements.txt`, use `INSTALL_CMD` = `pip install -e .` instead.

### DEV_CMD by FRAMEWORK

| FRAMEWORK | pip | poetry | uv |
|---|---|---|---|
| `fastapi` | `uvicorn app.main:app --reload` | `poetry run uvicorn app.main:app --reload` | `uv run uvicorn app.main:app --reload` |
| `django` | `python manage.py runserver` | `poetry run python manage.py runserver` | `uv run python manage.py runserver` |
| `flask` | `flask run --reload` | `poetry run flask run --reload` | `uv run flask run --reload` |
| `unknown` | `python src/main.py` | `poetry run python src/main.py` | `uv run python src/main.py` |

---

## Framework Variants

### FRAMEWORK=fastapi
- Entry point: `app/main.py` with `app = FastAPI()`
- Production: `uvicorn app.main:app` (or gunicorn with uvicorn workers)
- Async by default — use `async def` for route handlers

### FRAMEWORK=django
- Entry point: `manage.py`
- `BUILD_CMD` is not typically used — Django runs directly
- Override `TEST_CMD` to `python manage.py test` if `pytest-django` is not in dependencies

### FRAMEWORK=flask
- Entry point: `app.py` or `app/__init__.py`
- Set `FLASK_APP` env var if entry point is non-standard

---

## Directory Structure

```
src/ or app/          # Application code
  __init__.py
  main.py             # Entry point
tests/                # Test files
  conftest.py         # Shared fixtures
pyproject.toml        # Project metadata and dependencies
```

Django variant:
```
manage.py
project_name/
  settings.py
  urls.py
  wsgi.py
apps/
tests/
```

---

## Conventions

- Use `pyproject.toml` over `setup.py` / `requirements.txt` for new projects
- Ruff for both linting (`ruff check .`) and formatting (`ruff format .`) — these are distinct commands
- Type hints on all public function signatures
- pytest with `conftest.py` for shared fixtures
- Virtual environments are mandatory — never install globally

---

## Key Dependencies

- ruff (lint + format)
- pytest (testing)
- mypy (optional — static type checking)
- uvicorn (FastAPI/Starlette ASGI server)
- gunicorn (production WSGI/ASGI server)
