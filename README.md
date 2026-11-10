# betternotes

A GoodNotes-style handwriting app for iPad with a small web companion for Android and Linux.
Open file format, sync to your own cloud, no account, no telemetry, no subscription.

**Status: early development.** Nothing usable yet. See [PROGRESS.md](PROGRESS.md).

## Documents

- [docs/SIDESTORE.md](docs/SIDESTORE.md): install the iPad app without a Mac
- [docs/SCOPE.md](docs/SCOPE.md): what is being built
- [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md): how it is built
- [docs/DECISIONS.md](docs/DECISIONS.md): why

## How the iPad app is built

Nobody needs a Mac. Every push runs GitHub Actions: it generates the Xcode project from
`ios/project.yml`, builds an unsigned `betternotes.ipa`, and attaches it to the run. A tag
`v*` publishes it as a GitHub Release.

## Repository safety (for the owner of a fork)

The repository is public, so switch on GitHub's secret protection once:

1. Open the repository on github.com > **Settings** > **Advanced Security**
   (called "Code security" on some accounts).
2. Under **Secret Protection**, click **Enable**.
3. Under **Push protection**, click **Enable**.

With this, GitHub refuses a push that contains a known kind of key or token.

## Licence

Apps: [GPL-3.0-or-later](LICENSE). The format specification and JSON schema: CC0.
