<!-- Thanks for contributing to Jtech! -->

## Summary

<!-- One or two sentences: what changed and why. -->

## Affected sub-plugin(s)

<!-- Mark with [x] any that apply. -->

- [ ] Dislike (phantom reactions)
- [ ] Another SMTP
- [ ] Mini-mod
- [ ] Mod-categories
- [ ] Dumbcourse
- [ ] Shared infrastructure (plugin.rb, settings.yml, locales, lint/CI)

## Test plan

<!-- How you verified this works. Examples:
     - `bundle exec rake plugin:spec[jtech]` passes
     - `pnpm lint` clean
     - Manually toggled <setting>, observed <behavior>
     - Tested in admin UI: <flow> -->

## Checklist

- [ ] `pnpm lint` is clean
- [ ] `bundle exec rubocop` is clean
- [ ] New / changed settings have entries in `config/locales/server.en.yml` or `client.en.yml`
- [ ] New / changed behavior has a spec
- [ ] No Ruby file references a non-existent setting name
