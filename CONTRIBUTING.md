# Contributing to EduBoard

Thank you for your interest in contributing to the EduBoard ecosystem! EduBoard is an advanced, cross-platform collaborative whiteboard and document annotation platform built for educators and students.

## Code of Conduct

All contributors are expected to uphold our [Code of Conduct](CODE_OF_CONDUCT.md).

## Development Workflow

1. **Fork and Clone**:
   ```bash
   git clone https://github.com/rajeshreddy10/EduBoard_PDD.git
   cd EduBoard_PDD
   ```

2. **Branch Naming**:
   - `feature/<feature-name>`
   - `fix/<bug-description>`
   - `docs/<doc-update>`
   - `test/<test-expansion>`

3. **Install Dependencies**:
   - Web application: `npm install`
   - Mobile application: `cd apps/mobile/flutter && flutter pub get`

4. **Running Quality Checks**:
   - Web build: `npm run build:web`
   - Flutter analyze: `cd apps/mobile/flutter && flutter analyze`
   - Test suites: `pytest tests/selenium/test_selenium.py`

5. **Commit Conventions**:
   Follow Conventional Commits:
   - `feat(board): add polygon shape tool`
   - `fix(doccanvas): fix zoom matrix clamp`
   - `docs(readme): update deployment guide`

6. **Pull Requests**:
   - Ensure all automated tests pass in CI.
   - Fill out the PR template completely.
   - Request review from project maintainers.
