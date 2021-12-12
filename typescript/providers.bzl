TsInfo = provider(
    doc = "TypeScript",
    fields = {
        "name": "Package name",
        "package": "CommonJS package",
        "transitive_deps": "Depset of extra links",
        "transitive_declarations": "Depset of TypeScript declaration files",
        "transitive_descriptors": "Depset of package descriptors",
        "transitive_packages": "Depset of packages",
    },
)

SimpleTsCompilerInfo = provider(
    doc = "TypeScript compiler",
    fields = {
        "bin": "Executable",
    },
)

TsCompilerInfo = provider(
    doc = "TypeScript compiler",
    fields = {
        "bin": "Executable",
        "transpile_bin": "Executable",
        "runtime": "Runtime library",
    },
)

TsconfigInfo = provider(
    doc = "TypeScript config file",
    fields = {
        "config": "Config file",
        "name": "Package name",
        "package": "Package",
        "transitive_configs": "Depset of configs",
        "transitive_deps": "Depset of extra links",
        "transitive_descriptors": "Depset of package descriptors",
        "transitive_packages": "Depset of packages",
    },
)
