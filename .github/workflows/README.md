# GitHub Actions CI/CD

This directory contains GitHub Actions workflow configurations for continuous integration.

## Workflows

### CI Workflow (`ci.yml`)

Runs on every push to `main` branch and on all pull requests.

#### Jobs

1. **RuboCop**
   - Checks Ruby code style and quality
   - Runs in parallel for better performance
   - Uses Ruby 3.4.6

2. **RSpec**
   - Runs all test suites (model, system, etc.)
   - Includes MySQL database setup
   - Configures Chrome and ChromeDriver for system specs
   - Builds assets with npm
   - Generates test coverage reports
   - Uploads test results and coverage as artifacts

#### Environment Variables

The following environment variables are set in the CI workflow:

- `RAILS_ENV`: Set to `test`
- `DATABASE_URL`: MySQL connection string
- `LINE_CHANNEL_SECRET`: Test dummy value
- `LINE_CHANNEL_TOKEN`: Test dummy value
- `CI`: Automatically set by GitHub Actions (used for Capybara config)

#### System Specs Configuration

System specs use headless Chrome with special configurations for CI:
- `--no-sandbox`: Required for running Chrome in containers
- `--disable-dev-shm-usage`: Prevents shared memory issues
- `--disable-gpu`: Better compatibility in CI environments
- `--disable-software-rasterizer`: Improves stability
- `--disable-extensions`: Faster startup

#### Artifacts

The workflow uploads the following artifacts:
- **rspec-results**: JUnit format test results (XML)
- **coverage-report**: SimpleCov coverage reports (HTML)

## Local Testing

To test CI configurations locally:

```bash
# Install dependencies
bundle install
npm install

# Run RuboCop
bundle exec rubocop --parallel

# Build assets
npm run build
npm run build:css

# Run RSpec
bundle exec rspec
```

## Troubleshooting

### System Specs Failing

If system specs fail in CI but pass locally:
1. Check Chrome/ChromeDriver versions
2. Review Capybara timeout settings
3. Check for timing-dependent test failures
4. Verify CI-specific Chrome arguments in `spec/support/capybara.rb`

### Asset Build Failures

If asset building fails:
1. Ensure `package.json` scripts are correct
2. Check Node.js version compatibility
3. Clear npm cache: `npm cache clean --force`

### Database Connection Issues

If database tests fail:
1. Verify MySQL service is healthy
2. Check `DATABASE_URL` format
3. Ensure migrations are up to date
4. Review database setup steps in workflow
