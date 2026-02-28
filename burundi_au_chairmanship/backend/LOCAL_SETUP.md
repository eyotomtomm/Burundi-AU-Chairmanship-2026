# Local Development Setup

## Quick Start

### 1. Set Up Environment Variables

The application **requires** `DJANGO_SECRET_KEY` to be set. There is no fallback value for security reasons.

#### Option A: Using .env.local (Recommended)

```bash
# Copy the example file
cp .env.local.example .env.local

# Generate a secure secret key
python -c 'from django.core.management.utils import get_random_secret_key; print(get_random_secret_key())'

# Edit .env.local and paste your generated key
nano .env.local
```

Then load the environment variables:

```bash
# Install python-dotenv
pip install python-dotenv

# Load variables (or use django-environ package)
export $(cat .env.local | xargs)
```

#### Option B: Export Directly

```bash
# Generate and export in one command
export DJANGO_SECRET_KEY=$(python -c 'from django.core.management.utils import get_random_secret_key; print(get_random_secret_key())')

# Or set manually
export DJANGO_SECRET_KEY='your-generated-key-here'
export DJANGO_DEBUG=True
```

#### Option C: Add to Shell Profile

Add to `~/.bashrc`, `~/.zshrc`, or `~/.bash_profile`:

```bash
# Django Development
export DJANGO_SECRET_KEY='your-generated-key-here'
export DJANGO_DEBUG=True
export DJANGO_ALLOWED_HOSTS='localhost,127.0.0.1'
```

Then reload:
```bash
source ~/.zshrc  # or ~/.bashrc
```

### 2. Install Dependencies

```bash
pip install -r requirements.txt
```

### 3. Run Migrations

```bash
python manage.py migrate
```

### 4. Create Superuser (Optional)

```bash
python manage.py createsuperuser
```

### 5. Run Development Server

```bash
python manage.py runserver
```

The server will start at `http://localhost:8000`

## Troubleshooting

### "CRITICAL: DJANGO_SECRET_KEY environment variable is not set"

This means the `DJANGO_SECRET_KEY` environment variable is missing. This is intentional for security.

**Solution:**
1. Generate a key: `python -c 'from django.core.management.utils import get_random_secret_key; print(get_random_secret_key())'`
2. Set it: `export DJANGO_SECRET_KEY='your-key-here'`
3. Or create `.env.local` file (see Option A above)

### Environment Variables Not Loading

If using `.env.local`, ensure you're loading it:

```bash
# Method 1: Export manually
export $(cat .env.local | xargs)

# Method 2: Use python-dotenv
pip install python-dotenv
# Add to manage.py or wsgi.py:
# from dotenv import load_dotenv
# load_dotenv('.env.local')

# Method 3: Use direnv
# Install direnv and create .envrc file
```

### Database Issues

By default, SQLite is used for local development. To use PostgreSQL:

```bash
# Set DATABASE_URL
export DATABASE_URL='postgresql://user:password@localhost:5432/burundi_au_dev'
```

## Security Notes

### ⚠️ NEVER commit:
- `.env` or `.env.local` files
- `db.sqlite3` (contains user data)
- `media/` folder (uploaded files)
- `firebase-adminsdk*.json` (Firebase credentials)
- Any file containing secrets or API keys

### ✅ Safe to commit:
- `.env.example` (template without real values)
- `.env.local.example` (template for local dev)
- `requirements.txt`
- Source code (without secrets)

## Environment Variables Reference

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `DJANGO_SECRET_KEY` | **YES** | *(none)* | Django secret key for cryptographic signing |
| `DJANGO_DEBUG` | No | `True` | Debug mode (set to `False` in production) |
| `DJANGO_ALLOWED_HOSTS` | No | `*` | Comma-separated list of allowed hosts |
| `DATABASE_URL` | No | SQLite | PostgreSQL connection string |
| `DO_SPACES_KEY` | No | - | DigitalOcean Spaces access key (production only) |
| `DO_SPACES_SECRET` | No | - | DigitalOcean Spaces secret key (production only) |
| `DO_SPACES_BUCKET` | No | - | DigitalOcean Spaces bucket name (production only) |
| `DO_SPACES_ENDPOINT` | No | - | DigitalOcean Spaces endpoint URL (production only) |
| `FIREBASE_CREDENTIALS_PATH` | No | - | Path to Firebase admin SDK JSON file |

## Quick Commands

```bash
# Generate secret key
python -c 'from django.core.management.utils import get_random_secret_key; print(get_random_secret_key())'

# Run server
python manage.py runserver

# Run migrations
python manage.py migrate

# Create migrations
python manage.py makemigrations

# Create superuser
python manage.py createsuperuser

# Collect static files
python manage.py collectstatic

# Shell
python manage.py shell
```

## Development Workflow

1. **Set environment variables** (one-time setup)
2. **Install dependencies**: `pip install -r requirements.txt`
3. **Run migrations**: `python manage.py migrate`
4. **Start server**: `python manage.py runserver`
5. **Access admin**: http://localhost:8000/admin/
6. **Access API**: http://localhost:8000/api/

## VS Code / PyCharm Setup

### VS Code
Create `.vscode/launch.json`:
```json
{
  "version": "0.2.0",
  "configurations": [
    {
      "name": "Django",
      "type": "python",
      "request": "launch",
      "program": "${workspaceFolder}/manage.py",
      "args": ["runserver"],
      "django": true,
      "env": {
        "DJANGO_SECRET_KEY": "your-key-here",
        "DJANGO_DEBUG": "True"
      }
    }
  ]
}
```

### PyCharm
1. Run → Edit Configurations
2. Add Django Server configuration
3. Set environment variables in "Environment variables" field:
   ```
   DJANGO_SECRET_KEY=your-key-here;DJANGO_DEBUG=True
   ```

## Production Deployment

See `BACKEND_SUMMARY.md` for production deployment instructions.

**Key differences:**
- `DJANGO_DEBUG=False`
- `DJANGO_SECRET_KEY` must be a strong, unique value
- `DATABASE_URL` must point to PostgreSQL
- DigitalOcean Spaces configured for media files
- HTTPS enforced
- CORS restricted to specific domains

---

**Last Updated**: February 28, 2026
