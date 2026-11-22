# AGENTS.md (Matteo's fork)

Fork of `caioax/lyne-dots` (`upstream`), running as Matteo's Fedora desktop. Fedora setup, the Settings layer loaded from `hyprland/.config/hypr/local/matteo.lua`, and the rule for what belongs in this fork versus the Settings repo live in `$MATTEO_SETTINGS/hyprland/AGENTS.md`; read it before changing anything here.

- Work on `main`; prefix commits `fork:`; merge `upstream/main` instead of rebasing.
- Run `node --test tests/js && lua tests/lua/bind_presets.lua`; from inside a lyne session, run bats with `env -u LD_PRELOAD -u MALLOC_CONF`.
- After QML changes run `lyne reload`.
