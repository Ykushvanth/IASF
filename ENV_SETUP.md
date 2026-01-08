# Environment Setup

## Setting up API Keys

This project uses environment variables to store sensitive information like API keys. Never commit API keys to the repository!

### Steps to Configure:

1. **Create `.env` file** (in project root):
   ```bash
   cp .env.example .env
   ```

2. **Add your Groq API Key** to `.env`:
   ```
   GROQ_API_KEY=your_actual_groq_api_key_here
   ```

3. **Get your API Key**:
   - Visit [Groq Console](https://console.groq.com)
   - Create an API key if you don't have one
   - Copy and paste it into `.env`

4. **Never commit `.env`**:
   - The `.env` file is already in `.gitignore`
   - Only `.env.example` (template) should be in git

### Important:
- `.env.example` shows the required variables (safe to commit)
- `.env` contains actual secrets (never commit this)
- The app loads from `.env` at runtime using `flutter_dotenv`

## Running the App

The app automatically loads environment variables from `.env` using the `flutter_dotenv` package. Make sure `.env` is in the root directory before running.

```bash
flutter run
```
