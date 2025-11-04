module.exports = {
  root: true,
  parser: "@typescript-eslint/parser",
  parserOptions: { project: ["./tsconfig.json"] },
  plugins: ["@typescript-eslint"],
  extends: [
    "eslint:recommended",
    "plugin:@typescript-eslint/recommended"
  ],
  rules: {
    "quotes": ["error", "double"],
    "max-len": ["warn", { "code": 100, "ignoreUrls": true }],
    "@typescript-eslint/no-explicit-any": "off",
    "@typescript-eslint/no-non-null-assertion": "off",
    "arrow-parens": ["error", "always"],
    "object-curly-spacing": ["error", "always"]
  }
};
