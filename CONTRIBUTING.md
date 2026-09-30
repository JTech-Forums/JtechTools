# Contributing

Thanks for helping. Before you start, read the [repository rules](AGENTS.md). They're short, and every PR is reviewed against them.

## Getting set up

You need a Discourse development install with this repo linked into its `plugins/` folder as `jtech-tools`. [docs/development/testing.md](docs/development/testing.md) has the commands for setup, lint, specs and screenshots, and [architecture.md](docs/development/architecture.md) explains where things live.

## Making a change

1. Branch off `main`.
2. Keep the change inside one module where you can. If it has to reach across modules, say why in the PR.
3. Add or update specs. A bug fix comes with a spec that fails without it.
4. Run the checks:
   ```bash
   pnpm lint
   BUNDLE_GEMFILE=../discourse/Gemfile bundle exec rubocop
   BUNDLE_GEMFILE=../discourse/Gemfile bundle exec stree check Gemfile $(git ls-files '*.rb')
   ```
   Then run the specs for the module you touched, from the Discourse folder.
5. Open a PR. The template asks which module you touched and how you tested it.

## Adding a setting

1. Add it to `config/settings.yml` in the right `jtech_*` block, with `default:` and `client:`. Use `client: false` unless the browser needs it.
2. Describe it in `config/locales/server.en.yml`. Explain what it does and any catch.
3. Read it with `SiteSetting.<name>` and go through the module's `enabled?` helper.
4. Document it in the module's page under `docs/features/`. The settings table there is generated from the YAML.

## Adding a module

1. Create `sub_plugins/<name>.rb` and add it to the list in `plugin.rb`.
2. Put its Ruby in `lib/discourse_<name>/`, with an `enabled?` helper that includes `jtech_enabled`.
3. Give it its own settings block and an admin tab: see `admin/assets/javascripts/discourse/` and `assets/javascripts/discourse/initializers/jtech-tools-admin-nav.ts`.
4. Add `docs/features/<name>.md`, and link it from the README and `docs/README.md`.

## Bugs and ideas

Use the issue templates and say which module is involved. Security problems go through [SECURITY.md](SECURITY.md), not public issues.

## License

Contributions are released under the project's [GPL-3.0 license](LICENSE).
