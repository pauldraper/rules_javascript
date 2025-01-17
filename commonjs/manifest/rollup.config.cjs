const commonjs = require("@rollup/plugin-commonjs");
const { nodeResolve } = require("@rollup/plugin-node-resolve");

module.exports = {
  inlineDynamicImports: true,
  input: `${process.env.ROLLUP_INPUT_ROOT}/src/main.js`,
  output: { file: process.env.ROLLUP_OUTPUT, format: "cjs", sourcemap: true },
  plugins: [commonjs(), nodeResolve()],
};
