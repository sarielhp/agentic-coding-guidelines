# Rust and Ruby tooling acceptance tests

Run from the standards repository:

```bash
rtk proxy ruby -I test -e 'ARGV.each { |path| require File.expand_path(path) }' test/lifecycle_test.rb test/language_test.rb test/analysis_test.rb
```

The suite needs MRI Ruby 3.2 or later, minitest, Git, Make, and a Cargo toolchain with rustfmt and Clippy. It creates disposable repositories, local bare remotes, and installation destinations under the system temporary directory. Real Cargo fixtures use no external crate dependencies and run offline. Real minitest fixtures verify multi-file execution and failure propagation. Deep analyzers use deterministic executable adapters; this suite does not download advisory databases or install development tools.

Coverage includes checked Git failures, local-only commits, exact upstream publication, annotated tag verification, rejected push and resume, input changes, commit-hook mutations, opt-in installation and byte/permission verification, missing commands, artifact containment, Ruby scope promotion, parser failures, test failures, Cargo binaries/libraries/workspaces, version/lock synchronization, and fifth/twentieth milestone failures.

Validate changed Ruby implementation files with strict `ruby-audit --include-tests` and syntax/RuboCop review separately. Flay and dependency security analyzers must also be exercised in the adopting project's full gate once separately bootstrapped. The portable adapters verify their failure/report handling, not the completeness of external security or clone analyzers.
