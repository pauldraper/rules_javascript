# Webpack

Webpack bundles modules into one or more files.

<!-- START doctoc generated TOC please keep comment here to allow auto update -->
<!-- DON'T EDIT THIS SECTION, INSTEAD RE-RUN doctoc TO UPDATE -->

- [Install](#install)
- [Use](#use)

<!-- END doctoc generated TOC please keep comment here to allow auto update -->

## Install

Add rollup as an [external dependency](#external_dependencies).

## Use

**example/a.js**

```js
export const a = "apple";
```

**example/b.js**

```js
import { a } from "./a";

console.log(a);
```

**example/webpack.config.js**

```js
const path = require("path");

module.exports = {
  entry: path.resolve(`${process.env.WEBPACK_INPUT_ROOT}/b.js`),
  output: {
    filename: path.basename(process.env.WEBPACK_OUTPUT),
    path: path.resolve(path.dirname(process.env.WEBPACK_OUTPUT)),
  },
};
```

**example/BUILD.bzl**

```bzl
load("@better_rules_javascript//commonjs:rules.bzl", "cjs_root")
load("@better_rules_javascript//javascript:rules.bzl", "js_library")
load("@better_rules_javascript//rollup:rules.bzl", "configure_webpack", "webpack_bundle")

cjs_root(
  name = "root",
  descriptors = [],
)

js_library(
    name = "js",
    root = ":root",
    srcs = ["a.js", "b.js"],
)

js_library(
    name = "rollup_config",
    root = ":root",
    srcs = ["rollup.config.js"],
)

configure_webpack(
    name = "rollup",
    config = "rollup.config.cjs",
    config_dep = ":rollup_config",
    dep = "@npm//rollup:lib",
)

webpack_bundle(
    name = "bundle",
    dep = ":b",
    webpack = ":webpack",
)
```