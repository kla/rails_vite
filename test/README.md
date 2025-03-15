# ViteRailsLink Tests

This directory contains tests for the ViteRailsLink gem using Minitest.

## Running Tests

To run all tests:

```bash
bundle exec rake test
```

To run a specific test file:

```bash
bundle exec ruby -Ilib:test test/vite_rails_link/dev_server_config_test.rb
```

## Test Structure

- `test_helper.rb` - Sets up the test environment
- `vite_rails_link/dev_server_config_test.rb` - Tests for the DevServerConfig class
- `vite_rails_link/dev_server_test.rb` - Tests for the DevServer class
- `vite_rails_link/view_helper_test.rb` - Tests for the ViewHelper module

## Mocking

The tests use Mocha for mocking. This allows us to test the code without needing a real Rails application or Vite server.

## CI Integration

The tests are configured to work with Minitest CI for continuous integration. The CI results will be stored in the `test/reports` directory. 
