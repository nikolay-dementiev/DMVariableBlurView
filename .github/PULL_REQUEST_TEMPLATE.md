## What and why

## How it was tested

- [ ] `xcodebuild test` of the package on an iOS simulator
- [ ] `xcodebuild test` of the example app, if the change can affect what the blur draws
- [ ] `Scripts/lint.sh`, `Scripts/check-api.sh` and `Scripts/check-manifest.sh`
- [ ] Every new test fails without the change

## Public API and behaviour

- [ ] The public interface is unchanged, or `Fixtures/API/public-interface.txt` is updated in the same commit
- [ ] Every change that people using the package can notice is in `CHANGELOG.md`
- [ ] No new private name of the system, or the pull request names it and the README and the article How the blur works list it
