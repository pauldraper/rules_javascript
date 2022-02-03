load("//commonjs:providers.bzl", "CjsEntries", "CjsInfo", "create_dep", "default_strip_prefix", "output_name")
load("//util:path.bzl", "output", "runfile_path")
load(":providers.bzl", "JsInfo", "create_extra_deps", "target_deps")

def _js_library_impl(ctx):
    actions = ctx.actions
    cjs_info = ctx.attr.root[CjsInfo]
    js_deps = [dep[JsInfo] for dep in ctx.attr.deps]
    output_ = output(label = ctx.label, actions = actions)
    prefix = ctx.attr.prefix
    strip_prefix = ctx.attr.strip_prefix or default_strip_prefix(ctx)
    workspace_name = ctx.workspace_name
    label = ctx.label

    js = []
    for file in ctx.files.srcs:
        path = output_name(
            file = file,
            package_output = output_,
            prefix = prefix,
            root = cjs_info.package,
            strip_prefix = strip_prefix,
            workspace_name = workspace_name,
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

    transitive_deps = depset(
        target_deps(cjs_info.package, ctx.attr.deps) + create_extra_deps(cjs_info.package, label, ctx.attr.extra_deps),
        transitive = [js_info.transitive_deps for js_info in js_deps],
    )
    transitive_files = depset(
        cjs_info.descriptors + js,
        transitive = [js_info.transitive_files for js_info in js_deps],
    )
    transitive_packages = depset(
        [cjs_info.package],
        transitive = [js_info.transitive_packages for js_info in js_deps],
    )
    transitive_srcs = depset(
        transitive = [js_info.transitive_srcs for js_info in js_deps],
    )

    js_info = JsInfo(
        name = cjs_info.name,
        package = cjs_info.package,
        transitive_deps = transitive_deps,
        transitive_files = transitive_files,
        transitive_packages = transitive_packages,
        transitive_srcs = transitive_srcs,
    )

    cjs_entries = CjsEntries(
        name = cjs_info.name,
        package = cjs_info.package,
        transitive_packages = transitive_packages,
        transitive_deps = transitive_deps,
        transitive_files = depset(
            transitive = [transitive_files, transitive_srcs],
        ),
    )

    default_info = DefaultInfo(files = depset(js))

    return [cjs_entries, default_info, js_info]

js_library = rule(
    attrs = {
        "deps": attr.label_list(
            doc = "Dependencies.",
            providers = [JsInfo],
        ),
        "extra_deps": attr.string_dict(
            doc = "Extra dependencies.",
        ),
        "prefix": attr.string(
            doc = "Prefix to add. Defaults to empty.",
        ),
        "root": attr.label(
            mandatory = True,
            providers = [CjsInfo],
        ),
        "srcs": attr.label_list(
            allow_files = True,
            doc = "JavaScript files and data.",
        ),
        "strip_prefix": attr.string(
            doc = "Remove prefix, based on runfile path. Defaults to <workspace>/<package>.",
        ),
    },
    doc = "JavaScript library",
    implementation = _js_library_impl,
)
