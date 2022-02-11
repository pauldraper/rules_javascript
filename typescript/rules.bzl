load("@bazel_skylib//lib:paths.bzl", "paths")
load("@bazel_skylib//rules:common_settings.bzl", "BuildSettingInfo")
load("//commonjs:providers.bzl", "CjsEntries", "CjsInfo", "create_dep", "create_global", "create_package", "gen_manifest", "package_path")
load("//commonjs:rules.bzl", "cjs_root")
load("//nodejs:rules.bzl", "nodejs_binary")
load("//javascript:providers.bzl", "JsInfo", js_create_deps = "create_deps", js_create_extra_deps = "create_extra_deps", js_target_deps = "target_deps")
load("//util:path.bzl", "output", "output_name", "runfile_path")
load(":providers.bzl", "TsCompilerInfo", "TsInfo", "TsconfigInfo", "create_deps", "create_extra_deps", "declaration_path", "is_declaration", "is_directory", "is_json", "js_path", "map_path", "target_deps", "target_globals")

def _module(module):
    if module == "node":
        return "commonjs"
    return module

def _target(language):
    return language

def configure_ts_compiler(name, ts, tslib = None, visibility = None):
    """Configure TypeScript compiler.

    Args:
        name: Name to use for targets.
        ts: Typescript library.
        tslib: Tslib library.
        descriptors: List of package descriptors.
        visibility: Visibility.
    """

    nodejs_binary(
        main = "lib/tsc.js",
        name = "%s.bin" % name,
        dep = ts,
        visibility = ["//visibility:private"],
    )

    nodejs_binary(
        main = "dist/bundle.js",
        name = "%s.js_bin" % name,
        global_deps = [
            ts,
            "@better_rules_javascript_npm//argparse:lib",
            "@better_rules_javascript_npm//long:lib",
            "@better_rules_javascript_npm//protobufjs:lib",
        ],
        dep = "@better_rules_javascript//typescript/js-compiler:dist",
        visibility = ["//visibility:private"],
    )

    ts_compiler(
        name = name,
        bin = "%s.bin" % name,
        runtime = tslib,
        transpile_bin = "%s.js_bin" % name,
        visibility = visibility,
    )

def _ts_compiler_impl(ctx):
    ts_compiler_info = TsCompilerInfo(
        bin = ctx.attr.bin[DefaultInfo],
        transpile_bin = ctx.attr.transpile_bin[DefaultInfo],
        js_deps = [ctx.attr.runtime[JsInfo]] if ctx.attr.runtime else [],
        ts_deps = [ctx.attr.runtime[TsInfo]] if ctx.attr.runtime else [],
    )

    return [ts_compiler_info]

ts_compiler = rule(
    implementation = _ts_compiler_impl,
    attrs = {
        "bin": attr.label(
            cfg = "exec",
            doc = "Declaration compiler executable.",
            executable = True,
            mandatory = True,
        ),
        "transpile_bin": attr.label(
            cfg = "exec",
            doc = "JS compiler executable.",
            executable = True,
            mandatory = True,
        ),
        "runtime": attr.label(
            doc = "Runtime library.",
            providers = [JsInfo],
        ),
    },
)

def _tsconfig_impl(ctx):
    actions = ctx.actions
    cjs_info = ctx.attr.root[CjsInfo]
    deps = [ctx.attr.dep[TsconfigInfo]] if ctx.attr.dep else []
    label = ctx.label
    src = ctx.file.src
    output_ = output(label = ctx.label, actions = actions)

    workspace_name = ctx.workspace_name

    tsconfig_name = ctx.attr.path or output_name(
        file = src,
        label = label,
    )

    if src.path == "%s/%s" % (output_.path, tsconfig_name):
        tsconfig = src
    else:
        tsconfig = actions.declare_file(tsconfig_name)
        actions.symlink(target_file = src, output = tsconfig)

    tsconfig_info = TsconfigInfo(
        file = tsconfig,
        name = cjs_info.name,
        package = cjs_info.package,
        transitive_files = depset(
            [tsconfig] + cjs_info.descriptors,
            transitive = [tsconfig_info.transitive_files for tsconfig_info in deps],
        ),
        transitive_packages = depset(
            [cjs_info.package],
            transitive = [tsconfig_info.transitive_packages for tsconfig_info in deps],
        ),
        transitive_deps = depset(
            [create_dep(id = cjs_info.package.id, name = ctx.attr.dep[TsconfigInfo].name, dep = ctx.attr.dep[TsconfigInfo].package.id, label = ctx.attr.dep.label)] if ctx.attr.dep else [],
            transitive = [tsconfig_info.transitive_deps for tsconfig_info in deps],
        ),
    )

    cjs_entries = CjsEntries(
        name = cjs_info.name,
        package = cjs_info.package,
        transitive_packages = tsconfig_info.transitive_packages,
        transitive_deps = tsconfig_info.transitive_deps,
        transitive_files = tsconfig_info.transitive_files,
    )

    default_info = DefaultInfo(
        files = depset([tsconfig]),
    )

    return [cjs_info, default_info, tsconfig_info]

tsconfig = rule(
    attrs = {
        "dep": attr.label(
            providers = [TsconfigInfo],
        ),
        "root": attr.label(
            mandatory = True,
            providers = [CjsInfo],
        ),
        "path": attr.string(
            doc = "Strip prefix",
        ),
        "src": attr.label(
            mandatory = True,
            allow_single_file = [".json"],
        ),
    },
    implementation = _tsconfig_impl,
)

def _ts_library_impl(ctx):
    actions = ctx.actions
    config = ctx.attr._config[DefaultInfo]
    cjs_info = ctx.attr.root[CjsInfo]
    compiler = ctx.attr.compiler[TsCompilerInfo]
    declaration_prefix = ctx.attr.declaration_prefix
    fs_linker = ctx.file._fs_linker
    js_deps = compiler.js_deps + [dep[JsInfo] for dep in ctx.attr.deps if JsInfo in dep]
    js_prefix = ctx.attr.js_prefix
    label = ctx.label
    module = ctx.attr.module or _module(ctx.attr._module[BuildSettingInfo].value)
    output_ = output(ctx.label, actions)
    src_prefix = ctx.attr.src_prefix
    srcs = ctx.files.srcs
    strip_prefix = ctx.attr.strip_prefix
    target = ctx.attr.target or _target(ctx.attr._language[BuildSettingInfo].value)
    ts_deps = compiler.ts_deps + [dep[TsInfo] for dep in ctx.attr.deps if TsInfo in dep]
    tsconfig_info = ctx.attr.config[TsconfigInfo] if ctx.attr.config else None
    workspace_name = ctx.workspace_name

    transpile_tsconfig = actions.declare_file("%s.js-tsconfig.json" % ctx.attr.name)
    args = actions.args()
    if tsconfig_info:
        args.add("--config", tsconfig_info.file)
    args.add("--module", module)
    args.add("--out-dir", "%s/%s" % (output_.path, js_prefix) if js_prefix else output_.path)
    args.add("--root-dir", "%s/%s" % (output_.path, src_prefix) if src_prefix else output_.path)
    args.add("--target", target)
    args.add(transpile_tsconfig)
    actions.run(
        arguments = [args],
        executable = config.files_to_run.executable,
        tools = [config.files_to_run],
        outputs = [transpile_tsconfig],
    )

    transpile_package_manifest = actions.declare_file("%s.js-package-manifest.json" % ctx.attr.name)
    gen_manifest(
        actions = actions,
        manifest_bin = ctx.attr._manifest[DefaultInfo],
        manifest = transpile_package_manifest,
        deps = depset(
            create_deps(cjs_info.package, label, compiler.ts_deps),
            transitive = ([tsconfig_info.transitive_deps] if tsconfig_info else []) + [ts_info.transitive_deps for ts_info in compiler.ts_deps],
        ),
        globals = [],
        packages = depset(
            [cjs_info.package],
            transitive = ([tsconfig_info.transitive_packages] if tsconfig_info else []) + [ts_info.transitive_packages for ts_info in compiler.ts_deps],
        ),
        package_path = package_path,
    )

    declarations = []
    inputs = []
    js = []
    outputs = []
    js_srcs = []
    for file in ctx.files.srcs:
        path = output_name(
            file = file,
            prefix = src_prefix,
            strip_prefix = strip_prefix,
            label = label,
        )
        if file.path == "%s/%s" % (output_.path, path):
            ts_ = file
        else:
            ts_ = actions.declare_file(path)
            actions.symlink(
                target_file = file,
                output = ts_,
            )
        inputs.append(ts_)
        js_srcs.append(ts_)
        if not is_declaration(path):
            js_path_ = output_name(
                file = file,
                label = label,
                prefix = js_prefix,
                strip_prefix = strip_prefix,
            )
            declaration_path_ = output_name(
                file = file,
                label = label,
                prefix = declaration_prefix,
                strip_prefix = strip_prefix,
            )
            if is_json(path):
                if path == js_path_:
                    js_ = ts_
                else:
                    js_ = actions.declare_file(js_path_)
                    outputs.append(js_)
                js.append(js_)
                declarations.append(js_)
            else:
                js_outputs = []
                if is_directory(file.path):
                    js_ = actions.declare_directory(js_path_)
                    js.append(js_)
                    js_outputs.append(js_)
                    declaration = actions.declare_directory(declaration_path_)
                    declarations.append(declaration)
                    outputs.append(declaration)
                else:
                    js_ = actions.declare_file(js_path(js_path_))
                    js.append(js_)
                    js_outputs.append(js_)
                    map = actions.declare_file(map_path(js_path(js_path_)))
                    js_srcs.append(map)
                    js_outputs.append(map)
                    declaration = actions.declare_file(declaration_path(declaration_path_))
                    declarations.append(declaration)
                    outputs.append(declaration)

                args = actions.args()
                args.add("--config", transpile_tsconfig)
                args.add("--manifest", transpile_package_manifest)
                args.add(ts_.path)
                args.set_param_file_format("multiline")
                args.use_param_file("@%s", use_always = True)
                actions.run(
                    arguments = [args],
                    executable = compiler.transpile_bin.files_to_run.executable,
                    execution_requirements = {"supports-workers": "1"},
                    inputs = depset(
                        [ts_, transpile_package_manifest, transpile_tsconfig],
                        transitive = [tsconfig_info.transitive_files] if tsconfig_info else [],
                    ),
                    progress_message = "Transpiling %s to JavaScript" % file.path,
                    mnemonic = "TypeScriptTranspile",
                    outputs = js_outputs,
                    tools = [compiler.transpile_bin.files_to_run],
                )

    transitive_deps = depset(
        target_deps(cjs_info.package, ctx.attr.deps) + create_deps(cjs_info.package, label, compiler.ts_deps),
        transitive = [ts_info.transitive_deps for ts_info in ts_deps],
    )
    transitive_packages = depset(
        [cjs_info.package],
        transitive =
            [ts_info.transitive_packages for ts_info in ts_deps],
    )

    # compile
    if outputs:
        # create tsconfig
        tsconfig = actions.declare_file("%s.tsconfig.json" % ctx.attr.name)
        args = actions.args()
        if tsconfig_info:
            args.add("--config", tsconfig_info.file)
        args.add("--declaration-dir", "%s/%s" % (output_.path, declaration_prefix) if declaration_prefix else output_.path)
        args.add("--module", module)
        args.add("--root-dir", "%s/%s" % (output_.path, src_prefix) if src_prefix else output_.path)
        args.add("--target", target)
        args.add("--type-root", ("%s/node_modules/@types") % cjs_info.package.path)
        args.add(tsconfig)
        actions.run(
            arguments = [args],
            executable = config.files_to_run.executable,
            tools = [config.files_to_run],
            outputs = [tsconfig],
        )

        package_manifest = actions.declare_file("%s.package-manifest.json" % ctx.attr.name)
        gen_manifest(
            actions = actions,
            manifest_bin = ctx.attr._manifest[DefaultInfo],
            manifest = package_manifest,
            deps = depset(
                transitive = [transitive_deps] + ([tsconfig_info.transitive_deps] if tsconfig_info else []),
            ),
            globals = target_globals(ctx.attr.global_deps),
            packages = depset(
                transitive = [transitive_packages] + [target[TsInfo].transitive_packages for target in ctx.attr.global_deps if TsInfo in target] + ([tsconfig_info.transitive_packages] if tsconfig_info else []),
            ),
            package_path = package_path,
        )

        actions.run(
            arguments = ["-p", tsconfig.path],
            env = {
                "NODE_OPTIONS_APPEND": "-r ./%s" % fs_linker.path,
                "NODE_FS_PACKAGE_MANIFEST": package_manifest.path,
            },
            executable = compiler.bin.files_to_run.executable,
            inputs = depset(
                [package_manifest, fs_linker, tsconfig] + cjs_info.descriptors + inputs,
                transitive = ([tsconfig_info.transitive_files] if tsconfig_info else []) + [target[TsInfo].transitive_files for target in ctx.attr.global_deps if TsInfo in target] + [dep.transitive_files for dep in ts_deps],
            ),
            mnemonic = "TypeScriptCompile",
            progress_message = "Compiling %{label} TypeScript declarations",
            outputs = outputs,
            tools = [compiler.bin.files_to_run],
        )

    ts_info = TsInfo(
        name = cjs_info.name,
        package = cjs_info.package,
        transitive_deps = transitive_deps,
        transitive_files = depset(
            cjs_info.descriptors + declarations,
            transitive = [dep.transitive_files for dep in ts_deps],
        ),
        transitive_packages = transitive_packages,
        transitive_srcs = depset(
            transitive = [dep.transitive_srcs for dep in ts_deps],
        ),
    )

    js_info = JsInfo(
        name = cjs_info.name,
        package = cjs_info.package,
        transitive_deps = depset(
            js_target_deps(cjs_info.package, ctx.attr.deps) + js_create_deps(cjs_info.package, label, compiler.js_deps),
            transitive = [js_info.transitive_deps for js_info in js_deps],
        ),
        transitive_files = depset(
            cjs_info.descriptors + js,
            transitive = [js_info.transitive_files for js_info in js_deps],
        ),
        transitive_packages = depset(
            [cjs_info.package],
            transitive =
                [js_info.transitive_packages for js_info in js_deps],
        ),
        transitive_srcs = depset(
            js_srcs,
            transitive = [js_info.transitive_srcs for js_info in js_deps],
        ),
    )

    default_info = DefaultInfo(
        files = depset(declarations + js),
    )

    cjs_entries = CjsEntries(
        name = cjs_info.name,
        package = cjs_info.package,
        transitive_deps = depset(transitive = [js_info.transitive_deps, ts_info.transitive_deps]),
        transitive_packages = depset(transitive = [js_info.transitive_packages, ts_info.transitive_packages]),
        transitive_files = depset(transitive = [js_info.transitive_files, ts_info.transitive_files]),
    )

    return [default_info, cjs_entries, js_info, ts_info]

ts_library = rule(
    implementation = _ts_library_impl,
    attrs = {
        "_config": attr.label(
            cfg = "exec",
            default = "//typescript/config:bin",
            executable = True,
        ),
        "_fs_linker": attr.label(
            allow_single_file = [".js"],
            default = "//nodejs/fs-linker:file",
        ),
        "_language": attr.label(
            default = "//javascript:language",
            providers = [BuildSettingInfo],
        ),
        "_manifest": attr.label(
            cfg = "exec",
            default = "//commonjs/manifest:bin",
            executable = True,
        ),
        "_module": attr.label(
            default = "//javascript:module",
            providers = [BuildSettingInfo],
        ),
        "extra_deps": attr.string_dict(
            doc = "Extra dependencies.",
        ),
        "global_deps": attr.label_list(
            doc = "Types",
            providers = [[TsInfo]],
        ),
        "module": attr.string(
            doc = "Module type. By default, uses //javascript:module.",
        ),
        "srcs": attr.label_list(
            allow_files = True,
            doc = "TypeScript sources",
        ),
        "deps": attr.label_list(
            doc = "Dependencies",
            providers = [[JsInfo], [TsInfo]],
        ),
        "root": attr.label(
            mandatory = True,
            providers = [CjsInfo],
        ),
        "strip_prefix": attr.string(
            doc = "Strip prefix",
        ),
        "config": attr.label(
            providers = [TsconfigInfo],
        ),
        "declaration_prefix": attr.string(
            doc = "Prefix",
        ),
        "target": attr.string(
            doc = "Target language. By default, uses //javascript:language.",
        ),
        "src_prefix": attr.string(),
        "js_prefix": attr.string(),
        "compiler": attr.label(
            mandatory = True,
            providers = [TsCompilerInfo],
        ),
    },
)

def _ts_import_impl(ctx):
    actions = ctx.actions
    cjs_info = ctx.attr.root[CjsInfo]
    declaration_prefix = ctx.attr.declaration_prefix
    extra_deps = ctx.attr.extra_deps
    js_deps = [dep[JsInfo] for dep in ctx.attr.deps if JsInfo in dep]
    js_prefix = ctx.attr.js_prefix
    label = ctx.label
    output_ = output(label = ctx.label, actions = actions)
    strip_prefix = ctx.attr.strip_prefix
    ts_deps = [dep[TsInfo] for dep in ctx.attr.deps if TsInfo in dep]
    workspace_name = ctx.workspace_name

    declarations = []
    for file in ctx.files.declarations:
        path = output_name(
            file = file,
            prefix = declaration_prefix,
            strip_prefix = strip_prefix,
            label = label,
        )
        if file.path == "%s/%s" % (output_.path, path):
            declaration = file
        else:
            declaration = actions.declare_file(path)
            actions.symlink(
                target_file = file,
                output = declaration,
            )
        declarations.append(declaration)

    js = []
    for file in ctx.files.js:
        path = output_name(
            file = file,
            label = label,
            prefix = js_prefix,
            strip_prefix = strip_prefix,
        )
        if file.path == "%s/%s" % (output_.path, path):
            js_ = file
        else:
            js_ = actions.declare_file(path)
            actions.symlink(
                target_file = file,
                output = js_,
            )
        js.append(js_)

    ts_info = TsInfo(
        name = cjs_info.name,
        package = cjs_info.package,
        transitive_files = depset(
            cjs_info.descriptors + declarations,
            transitive = [ts_info.transitive_files for ts_info in ts_deps],
        ),
        transitive_deps = depset(
            target_deps(cjs_info.package, ctx.attr.deps) + create_extra_deps(cjs_info.package, label, extra_deps),
            transitive = [ts_info.transitive_deps for ts_info in ts_deps],
        ),
        transitive_srcs = depset(),  # TODO
        transitive_packages = depset(
            [cjs_info.package],
            transitive = [ts_info.transitive_packages for ts_info in ts_deps],
        ),
    )

    js_info = JsInfo(
        name = cjs_info.name,
        package = cjs_info.package,
        transitive_deps = depset(
            js_target_deps(cjs_info.package, ctx.attr.deps) + create_extra_deps(cjs_info.package, label, extra_deps),
            transitive = [js_info.transitive_deps for js_info in js_deps],
        ),
        transitive_files = depset(
            cjs_info.descriptors + js,
            transitive = [js_info.transitive_files for js_info in js_deps],
        ),
        transitive_packages = depset(
            [cjs_info.package],
            transitive = [js_info.transitive_packages for js_info in js_deps],
        ),
        transitive_srcs = depset(
            transitive = [js_info.transitive_srcs for js_info in js_deps],
        ),
    )

    cjs_entries = CjsEntries(
        name = cjs_info.name,
        package = cjs_info.package,
        transitive_packages = depset(transitive = [js_info.transitive_packages, ts_info.transitive_packages]),
        transitive_deps = depset(transitive = [js_info.transitive_deps, ts_info.transitive_deps]),
        transitive_files = depset(
            transitive = [js_info.transitive_files, ts_info.transitive_files, js_info.transitive_srcs, ts_info.transitive_srcs],
        ),
    )

    default_info = DefaultInfo(
        files = depset(declarations + js),
    )

    return [cjs_entries, js_info, ts_info]

ts_import = rule(
    implementation = _ts_import_impl,
    attrs = {
        "declarations": attr.label_list(
            doc = "Typescript declarations",
            allow_files = True,
        ),
        "deps": attr.label_list(
            doc = "Dependencies",
            providers = [[JsInfo], [TsInfo]],
        ),
        "extra_deps": attr.string_dict(
            doc = "Extra dependencies.",
        ),
        "js": attr.label_list(
            doc = "JavaScript",
            allow_files = True,
        ),
        "root": attr.label(
            doc = "CommonJS root",
            mandatory = True,
            providers = [CjsInfo],
        ),
        "strip_prefix": attr.string(
            doc = "Strip prefix, defaults to CjsRoot prefix",
        ),
        "declaration_prefix": attr.string(),
        "js_prefix": attr.string(
            doc = "Prefix",
        ),
    },
    doc = "Import existing files",
)
