'use strict';Object.defineProperty(exports,'__esModule',{value:true});var path=require('path'),Module=require('module'),fs=require('fs'),url=require('url');function _interopDefaultLegacy(e){return e&&typeof e==='object'&&'default'in e?e:{'default':e}}function _interopNamespace(e){if(e&&e.__esModule)return e;var n=Object.create(null);if(e){Object.keys(e).forEach(function(k){if(k!=='default'){var d=Object.getOwnPropertyDescriptor(e,k);Object.defineProperty(n,k,d.get?d:{enumerable:true,get:function(){return e[k]}});}})}n["default"]=e;return Object.freeze(n)}var path__default=/*#__PURE__*/_interopDefaultLegacy(path);var path__namespace=/*#__PURE__*/_interopNamespace(path);var Module__default=/*#__PURE__*/_interopDefaultLegacy(Module);var fs__namespace=/*#__PURE__*/_interopNamespace(fs);var url__namespace=/*#__PURE__*/_interopNamespace(url);function createCommonjsModule(fn, basedir, module) {
	return module = {
		path: basedir,
		exports: {},
		require: function (path, base) {
			return commonjsRequire(path, (base === undefined || base === null) ? module.path : base);
		}
	}, fn(module, module.exports), module.exports;
}

function commonjsRequire () {
	throw new Error('Dynamic requires are not currently supported by @rollup/plugin-commonjs');
}var collection = createCommonjsModule(function (module, exports) {
Object.defineProperty(exports, "__esModule", { value: true });
exports.Trie = void 0;
class Trie {
    constructor() {
        this.data = { children: new Map() };
    }
    getClosest(key) {
        let data = this.data;
        let i;
        for (i = 0; i < key.length && data; i++) {
            const k = key[i];
            const newData = data.children.get(k);
            if (!newData) {
                break;
            }
            data = newData;
        }
        return { rest: key.slice(i), value: data.value };
    }
    put(key, value) {
        let data = this.data;
        for (const k of key) {
            let newData = data.children.get(k);
            if (!newData) {
                newData = { children: new Map() };
                data.children.set(k, newData);
            }
            data = newData;
        }
        data.value = value;
    }
}
exports.Trie = Trie;

});var resolve$1 = createCommonjsModule(function (module, exports) {
Object.defineProperty(exports, "__esModule", { value: true });
exports.Resolver = void 0;


function moduleParts(path_) {
    return path_ ? path_.split("/") : [];
}
function pathParts(path_) {
    path_ = path__default["default"].resolve(path_);
    return path_.split("/").slice(1);
}
class Resolver {
    constructor(packages) {
        this.packages = packages;
    }
    resolve(parent, request) {
        if (request.startsWith(".") || request.startsWith("/")) {
            throw new Error(`Specifier "${request}" is not for a package`);
        }
        const { value: package_ } = this.packages.getClosest(pathParts(parent));
        if (!package_) {
            throw new Error(`File "${parent}" is not part of any known package`);
        }
        const { rest: depRest, value: dep } = package_.deps.getClosest(moduleParts(request));
        if (!dep) {
            throw new Error(`Package "${package_.id}" does not have any dependency for "${request}"`);
        }
        return { package: dep, inner: depRest.join("/") };
    }
    static create(packageTree, runfiles) {
        const resolve = (path_) => path__default["default"].resolve(runfiles ? `${process.env.RUNFILES_DIR}/${path_}` : path_);
        const packages = new collection.Trie();
        for (const [id, package_] of packageTree.entries()) {
            const path_ = pathParts(resolve(package_.path));
            const deps = new collection.Trie();
            for (const [name, dep] of package_.deps.entries()) {
                const package_ = packageTree.get(dep);
                if (!package_) {
                    throw new Error(`Package "${dep}" referenced by "${id}" does not exist`);
                }
                const path_ = resolve(package_.path);
                deps.put(moduleParts(name), path_);
            }
            packages.put(path_, { id: id, deps });
        }
        return new Resolver(packages);
    }
}
exports.Resolver = Resolver;

});var json = createCommonjsModule(function (module, exports) {
Object.defineProperty(exports, "__esModule", { value: true });
exports.JsonFormat = void 0;
(function (JsonFormat) {
    function parse(format, string) {
        return format.fromJson(JSON.parse(string));
    }
    JsonFormat.parse = parse;
    function stringify(format, value) {
        return JSON.stringify(format.toJson(value));
    }
    JsonFormat.stringify = stringify;
})(exports.JsonFormat || (exports.JsonFormat = {}));
(function (JsonFormat) {
    function array(elementFormat) {
        return new ArrayJsonFormat(elementFormat);
    }
    JsonFormat.array = array;
    function map(keyFormat, valueFormat) {
        return new MapJsonFormat(keyFormat, valueFormat);
    }
    JsonFormat.map = map;
    function object(format) {
        return new ObjectJsonFormat(format);
    }
    JsonFormat.object = object;
    function defer(format) {
        return {
            fromJson(json) {
                return format().fromJson(json);
            },
            toJson(value) {
                return format().toJson(value);
            },
        };
    }
    JsonFormat.defer = defer;
    function set(format) {
        return new SetJsonFormat(format);
    }
    JsonFormat.set = set;
    function string() {
        return new StringJsonFormat();
    }
    JsonFormat.string = string;
})(exports.JsonFormat || (exports.JsonFormat = {}));
class ArrayJsonFormat {
    constructor(elementFormat) {
        this.elementFormat = elementFormat;
    }
    fromJson(json) {
        return json.map((element) => this.elementFormat.fromJson(element));
    }
    toJson(json) {
        return json.map((element) => this.elementFormat.toJson(element));
    }
}
class ObjectJsonFormat {
    constructor(format) {
        this.format = format;
    }
    fromJson(json) {
        const result = {};
        for (const key in this.format) {
            result[key] = this.format[key].fromJson(json[key]);
        }
        return result;
    }
    toJson(value) {
        const json = {};
        for (const key in this.format) {
            json[key] = this.format[key].toJson(value[key]);
        }
        return json;
    }
}
class MapJsonFormat {
    constructor(keyFormat, valueFormat) {
        this.keyFormat = keyFormat;
        this.valueFormat = valueFormat;
    }
    fromJson(json) {
        return new Map(json.map(({ key, value }) => [
            this.keyFormat.fromJson(key),
            this.valueFormat.fromJson(value),
        ]));
    }
    toJson(value) {
        return [...value.entries()].map(([key, value]) => ({
            key: this.keyFormat.toJson(key),
            value: this.valueFormat.toJson(value),
        }));
    }
}
class SetJsonFormat {
    constructor(format) {
        this.format = format;
    }
    fromJson(json) {
        return new Set(json.map((element) => this.format.fromJson(element)));
    }
    toJson(value) {
        return [...value].map((element) => this.format.toJson(element));
    }
}
class StringJsonFormat {
    fromJson(json) {
        return json;
    }
    toJson(value) {
        return value;
    }
}

});var src = createCommonjsModule(function (module, exports) {
Object.defineProperty(exports, "__esModule", { value: true });
exports.PackageTree = exports.Package = void 0;

class Package {
}
exports.Package = Package;
(function (Package) {
    function json$1() {
        return json.JsonFormat.object({
            id: json.JsonFormat.string(),
            deps: json.JsonFormat.map(json.JsonFormat.string(), json.JsonFormat.string()),
            path: json.JsonFormat.string(),
        });
    }
    Package.json = json$1;
})(Package = exports.Package || (exports.Package = {}));
(function (PackageTree) {
    function json$1() {
        return json.JsonFormat.map(json.JsonFormat.string(), Package.json());
    }
    PackageTree.json = json$1;
})(exports.PackageTree || (exports.PackageTree = {}));

});const manifestPath = process.env.NODE_PACKAGE_MANIFEST;
if (!manifestPath) {
    throw new Error("NODE_PACKAGE_MANIFEST is not set");
}
const packageTree = json.JsonFormat.parse(src.PackageTree.json(), fs__namespace.readFileSync(manifestPath, "utf8"));
const resolver = resolve$1.Resolver.create(packageTree, true);
function resolve(specifier, context, defaultResolve) {
    if (!context.parentURL && path__namespace.extname(specifier) == "") {
        return { format: "commonjs", url: specifier };
    }
    const parent = context.parentURL !== undefined ? new URL(context.parentURL) : undefined;
    if (Module__default["default"].builtinModules.includes(specifier) ||
        (parent === null || parent === void 0 ? void 0 : parent.protocol) !== "file:" ||
        specifier == "." ||
        specifier == ".." ||
        specifier.startsWith("./") ||
        specifier.startsWith("../") ||
        specifier.startsWith("/") ||
        specifier.startsWith("file://")) {
        return defaultResolve(specifier, context, defaultResolve);
    }
    const resolved = resolver.resolve(parent.pathname, specifier);
    const [base, packageName] = resolved.package.split("/node_modules/", 2);
    specifier = packageName;
    if (resolved.inner) {
        specifier = `${specifier}/${resolved.inner}`;
    }
    return defaultResolve(specifier, { ...context, parentURL: url__namespace.pathToFileURL(`${base}/_`) }, defaultResolve);
}exports.resolve=resolve;