<!-- Thanks for contributing to Jtech! -->

## Summary

<!-- One or two sentences: what changed and why. -->

## Affected module(s)

<!-- Mark with [x] any that apply. -->

- [ ] Moderator tools
- [ ] Mini-mod
- [ ] Dislike
- [ ] Disteleplus
- [ ] REQ-PM
- [ ] Dumbcourse
- [ ] Smart search
- [ ] Pop-ups
- [ ] Another SMTP
- [ ] Translator tweaks
- [ ] JTech theme
- [ ] Shared (plugin.rb, settings, locales, docs, lint/CI)

## Test plan

<!-- How you verified this works. Examples:
     - `bin/rspec plugins/jtech-tools/spec/...` passes
     - `pnpm lint` clean
     - Manually toggled <setting>, observed <behavior>
     - Tested in admin UI: <flow> -->

## Checklist

- [ ] `pnpm lint` is clean
- [ ] `bundle exec rubocop` is clean
- [ ] New / changed settings have entries in `config/locales/server.en.yml` or `client.en.yml`
- [ ] New / changed behavior has a spec (a bug fix has one that fails without it)
- [ ] Follows the [repository rules](../AGENTS.md): no access past core, visibility checked, nothing core already does
- [ ] No Ruby file references a non-existent setting name
