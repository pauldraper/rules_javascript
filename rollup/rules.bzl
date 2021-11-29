load("@bazel_skylib//lib:shell.bzl", "shell")
load("//commonjs:providers.bzl", "cjs_path")
load("//commonjs:rules.bzl", "gen_manifest")
load("//javascript:providers.bzl", "JsInfo")
load("//nodejs:rules.bzl", "nodejs_binary")
load("//util:path.bzl", "runfile_path")
load(":providers.bzl", "RollupInfo")

_VFS_ROOT = "bazel-rollup"

_VFS_CONFIG_ROOT = "bazel-rollup-config"

def _rollup_impl(ctx):
    rollup_info = RollupInfo(
        bin = ctx.attr.bin[DefaultInfo].files_to_run,
        config_path = "%s/%s" % (runfile_path(ctx, ctx.attr.config_dep[JsInfo].package), ctx.attr.config),
    )

    return [rollup_info]

rollup = rule(
    attrs = {
        "bin": attr.label(
            doc = "Rollup executable",
            executable = True,
            mandatory = True,
            cfg = "exec",
        ),
        "config_dep": attr.label(
            cfg = "exec",
            mandatory = True,
            providers = [JsInfo],
        ),
        "config": attr.string(
            mandatory = True,
        ),
    },
    doc = "Rollup tools",
    implementation = _rollup_impl,
)

def configure_rollup(name, dep, config_dep, config, visibility = None):
    """Set up rollup tools.

    Args:
        name: Name
        dep: Rollup library
        config_dep: Configuration dependency
        config: Configuration path
    """

    nodejs_binary(
        main = "dist/bin/rollup",
        name = "%s_bin" % name,
        dep = dep,
        other_deps = [config_dep],
        visibility = visibility,
    )

    rollup(
        name = name,
        config_dep = config_dep,
        config = config,
        bin = "%s_bin" % name,
        visibility = visibility,
    )

def _rollup_bundle_impl(ctx):
    dep = ctx.attr.dep[JsInfo]
    rollup = ctx.attr.rollup[RollupInfo]

    package_manifest = ctx.actions.declare_file("%s/packages.json" % ctx.label.name)
    gen_manifest(
        actions = ctx.actions,
        deps = dep.transitive_deps,
        globals = [],
        manifest = package_manifest,
        manifest_bin = ctx.attr._manifest[DefaultInfo],
        packages = dep.transitive_packages,
        runfiles = False,
    )

    bundle = ctx.actions.declare_file("%s/bundle.js" % ctx.label.name)

    args = []
    args.append("--config")
    args.append("./%s.runfiles/%s" % (rollup.bin.executable.path, rollup.config_path))

    ctx.actions.run(
        env = {
            "NODE_FS_PACKAGE_MANIFEST": package_manifest.path,
            "NODE_OPTIONS_APPEND": "-r ./%s" % ctx.file._fs_linker.path,
            "ROLLUP_INPUT_ROOT": dep.package.path,
            "ROLLUP_OUTPUT": bundle.path,
        },
        executable = rollup.bin.executable,
        tools = [rollup.bin],
        arguments = args,
        inputs = depset(
            [package_manifest, ctx.file._fs_linker],
            transitive = [
                dep.transitive_descriptors,
                dep.transitive_js,
                dep.transitive_srcs,
            ],
        ),
        outputs = [bundle],
    )

    default_info = DefaultInfo(files = depset([bundle]))

    return [default_info]

rollup_bundle = rule(
    attrs = {
        "dep": attr.label(
            doc = "JavaScript dependencies",
            providers = [JsInfo],
        ),
        "rollup": attr.label(
            doc = "Rollup tools",
            mandatory = True,
            providers = [RollupInfo],
        ),
        "_manifest": attr.label(
            cfg = "exec",
            executable = True,
            default = "//commonjs/manifest:bin",
        ),
        "_fs_linker": attr.label(
            allow_single_file = True,
            default = "//nodejs/fs-linker:file",
        ),
    },
    doc = "Rollup bundle",
    implementation = _rollup_bundle_impl,
)
