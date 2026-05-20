# Contributing to Jtech

Thanks for considering a contribution. Jtech is one Discourse plugin that wraps five sub-plugins. Each sub-plugin keeps its own Ruby namespace, settings prefix, and master enable switch — so your change should usually live entirely inside one sub-plugin's territory.

## Project layout

See [`README.md`](./README.md) for the directory map. The short version:

- **`plugin.rb`** — master registration; do not duplicate `enabled_site_setting` or magic-header keys.
- **`sub_plugins/<name>.rb`** — each old plugin's body, instance_eval'd. Edit the relevant one.
- **`lib/<namespace>/`** — pure Ruby helpers per sub-plugin.
- **`app/`**, **`db/migrate/`**, **`assets/`**, **`public/`** — standard Discourse plugin layout.
- **`config/settings.yml`** — one section per admin tab. Keep setting keys unchanged in PRs that only reorganize.
- **`config/locales/{server,client}.en.yml`** — every site setting must have a translation in one or the other.

## Development workflow

1. Fork → branch off `main`.
2. Make your change. Stay inside one sub-plugin where possible. Don't introduce cross-sub-plugin coupling without raising it in the PR description.
3. Run lint locally:
   ```bash
   pnpm install
   bundle install
   pnpm lint              # ESLint + Prettier + Stylelint + template-lint
   bundle exec rubocop    # Ruby
   ```
4. Run the relevant specs in a Discourse dev install:
   ```bash
   # From your Discourse root, with this plugin symlinked into plugins/
   bundle exec rake plugin:spec[jtech]
   ```
5. Open a PR. The template will ask which sub-plugin you touched and how you tested.

## Style

- **Ruby**: `rubocop-discourse` + `syntax_tree` — `bundle exec stree write Gemfile *.rb sub_plugins/*.rb lib/**/*.rb` if anything's off.
- **JS / `.gjs`**: ESLint + Prettier via `@discourse/lint-configs`. `pnpm lint:fix` rewrites for you.
- **SCSS**: Stylelint via `@discourse/lint-configs/stylelint`. Same `lint:fix`.
- **Comments**: Don't restate what the code does. Comment **why** when a constraint isn't obvious.

## Adding a setting

1. Add to `config/settings.yml` under the right `jtech_*` section. Always declare `default:` and `client:` (use `client: false` if unsure).
2. Add a translation in `config/locales/server.en.yml` (admin label) or `client.en.yml` (if used by JS UI).
3. Reference the setting via `SiteSetting.<name>` in Ruby; never duplicate its value as a constant.
4. If it gates behavior, early-return when it's disabled rather than wrapping the whole module.

## Adding a setting category (new admin tab)

1. Add the top-level key to `config/settings.yml`.
2. Add a translation under `en.site_settings.categories.<key>` in `config/locales/server.en.yml`.

## Reporting bugs / requesting features

Use the GitHub issue templates. Tag which sub-plugin is affected — it speeds up routing.

## Security

See [`SECURITY.md`](./SECURITY.md) for the disclosure policy. Don't open public issues for vulnerabilities.

## License

By contributing you agree your work will ship under the project's [GPL-3.0 license](./LICENSE).
