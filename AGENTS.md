# Rules for changing DMVariableBlurView

These rules are for anyone who changes this package, by hand or with a tool. The reasons and the
details are in [ENGINEERING.md](ENGINEERING.md) and [CONTRIBUTING.md](CONTRIBUTING.md).

- The public interface is a contract. Classify every change as none, additive or breaking, as
  ENGINEERING.md defines them. A change of observable behaviour is breaking.
- Add no dependency without the maintainer's approval.
- Test through the public API and the `package` declarations of the module, with no
  `@testable import`. Every new test must be able to fail: name the change to the code that it
  fails on.
- Keep the build free of warnings, and run `Scripts/lint.sh`, `Scripts/check-lint-contract.sh`,
  `Scripts/check-api.sh` and `Scripts/check-manifest.sh` before a pull request.
- Library code never stops its host: no `fatalError`, no force unwrap, no `try!` and no `as!`.
- A new private name of the system is the maintainer's decision: name it in the pull request, and
  add it to the lists in the README and in the article How the blur works.
- One topic per commit, with a conventional prefix: `test:`, `fix:`, `feat:`, `refactor:`,
  `docs:`, `chore:`, `ci:` or `perf:`.
