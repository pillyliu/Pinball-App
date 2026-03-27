fastlane documentation
----

# Installation

Make sure you have the latest version of the Xcode command line tools installed:

```sh
xcode-select --install
```

For _fastlane_ installation instructions, see [Installing _fastlane_](https://docs.fastlane.tools/#installing-fastlane)

# Available Actions

## iOS

### ios test

```sh
[bundle exec] fastlane ios test
```

Run practice migration XCTest suite

### ios build

```sh
[bundle exec] fastlane ios build
```

Build an App Store archive without uploading

### ios upload_build

```sh
[bundle exec] fastlane ios upload_build
```

Optionally bump version/build, archive, and upload the binary to App Store Connect

### ios submit_review

```sh
[bundle exec] fastlane ios submit_review
```

Update App Store Connect metadata, select a build, and submit the version for review

### ios release_history

```sh
[bundle exec] fastlane ios release_history
```

Read recent App Store release notes and promotional text for drafting

### ios beta

```sh
[bundle exec] fastlane ios beta
```

Alias for upload_build

### ios release

```sh
[bundle exec] fastlane ios release
```

Alias for submit_review

----

This README.md is auto-generated and will be re-generated every time [_fastlane_](https://fastlane.tools) is run.

More information about _fastlane_ can be found on [fastlane.tools](https://fastlane.tools).

The documentation of _fastlane_ can be found on [docs.fastlane.tools](https://docs.fastlane.tools).
