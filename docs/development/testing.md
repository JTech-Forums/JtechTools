# Setting up, testing and CI

## A development forum

Clone Discourse, link this repo into its `plugins/` directory, and use a lowercase folder name. Discourse builds the stylesheet URL from the folder name and only accepts lowercase.

```bash
git clone https://github.com/discourse/discourse.git
cd discourse
ln -s /path/to/JtechTools plugins/jtech-tools
bin/setup            # or follow Discourse's own dev-install guide
LOAD_PLUGINS=1 bin/rails s
```

## Lint

From this repo:

```bash
pnpm install
pnpm lint          # ESLint, Prettier, Stylelint, TypeScript, Dumbcourse build check + tests, scripts
pnpm lint:fix      # fixes what it can
```

Ruby lint uses Discourse's own gems, so run it from this repo with Discourse's Gemfile:

```bash
BUNDLE_GEMFILE=../discourse/Gemfile bundle exec rubocop
BUNDLE_GEMFILE=../discourse/Gemfile bundle exec stree check Gemfile $(git ls-files '*.rb')
BUNDLE_GEMFILE=../discourse/Gemfile bundle exec stree write <files>   # to fix
```

## Specs

From the Discourse folder:

```bash
LOAD_PLUGINS=1 RAILS_ENV=test bin/rake db:migrate
LOAD_PLUGINS=1 bin/rspec plugins/jtech-tools/spec                    # everything
LOAD_PLUGINS=1 bin/rspec plugins/jtech-tools/spec/requests/mini_mod_security_spec.rb
```

System specs (`spec/system/`) drive a real browser. After changing frontend code, rebuild the plugin's JavaScript first, or the browser runs the old build:

```bash
LOAD_PLUGINS=1 RAILS_ENV=test bin/rake assets:precompile:build_plugins
```

Specs that only take screenshots skip themselves unless `JTECH_SCREENSHOT_GALLERY=1` (pop-up gallery) or `JTECH_COMPREHENSIVE_SHOTS=1` is set. Screenshots land in `tmp/capybara/`.

Dumbcourse has its own fast unit tests: `pnpm dumbcourse:test`.

## CI

| Workflow | When | What |
| --- | --- | --- |
| `discourse-plugin.yml` | every push and PR | Discourse's standard plugin CI: linting, backend specs, system specs, plus the Dumbcourse build and tests |
| `feature-screenshots.yml` | every push and PR | Runs the feature screenshot spec and uploads the PNGs as an artifact |
| `comprehensive-screenshots.yml` | by hand | The large screenshot matrix, for visual review |

A PR is ready when all of them are green.

## Writing a migration

Migrations run on existing forums and on brand-new test databases. When a migration switches a core setting on to keep an old behavior, guard it with `Migration::Helpers.existing_site?`. Otherwise every new install, and every CI run, gets the old behavior too.
