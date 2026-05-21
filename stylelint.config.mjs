export default {
  extends: ["@discourse/lint-configs/stylelint"],
  rules: {
    // The shared config enforces `rgb(...)` over `rgba(...)`. Both are valid
    // CSS Color Level 4, but Discourse's Sass pipeline doesn't always honour
    // the alpha argument on 4-arg `rgb()`, which silently dropped the alpha
    // on whisper.scss after the lint:fix sweep and broke the whisper UI tint.
    // Keep `rgba(...)` for any color that carries an alpha.
    "color-function-alias-notation": null,
  },
};
