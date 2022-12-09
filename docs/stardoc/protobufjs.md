# Contents

<!-- START doctoc generated TOC please keep comment here to allow auto update -->
<!-- DON'T EDIT THIS SECTION, INSTEAD RE-RUN doctoc TO UPDATE -->

- [//protobufjs:providers.bzl](#protobufjsprovidersbzl)
  - [JsProtobuf](#jsprotobuf)
- [//protobufjs:rules.bzl](#protobufjsrulesbzl)
  - [js_proto](#js_proto)
  - [js_proto_library](#js_proto_library)
  - [configure_js_proto](#configure_js_proto)

<!-- END doctoc generated TOC please keep comment here to allow auto update -->

# //protobufjs:providers.bzl

<!-- Generated with Stardoc: http://skydoc.bazel.build -->

<a id="#JsProtobuf"></a>

## JsProtobuf

<pre>
JsProtobuf(<a href="#JsProtobuf-runtime">runtime</a>, <a href="#JsProtobuf-bin">bin</a>)
</pre>

**FIELDS**

| Name                                   | Description          |
| :------------------------------------- | :------------------- |
| <a id="JsProtobuf-runtime"></a>runtime | Runtime dependencies |
| <a id="JsProtobuf-bin"></a>bin         | Executable           |

# //protobufjs:rules.bzl

<!-- Generated with Stardoc: http://skydoc.bazel.build -->

<a id="#js_proto"></a>

## js_proto

<pre>
js_proto(<a href="#js_proto-name">name</a>, <a href="#js_proto-bin">bin</a>, <a href="#js_proto-runtime">runtime</a>)
</pre>

**ATTRIBUTES**

| Name                                 | Description                    | Type                                                               | Mandatory | Default |
| :----------------------------------- | :----------------------------- | :----------------------------------------------------------------- | :-------- | :------ |
| <a id="js_proto-name"></a>name       | A unique name for this target. | <a href="https://bazel.build/docs/build-ref.html#name">Name</a>    | required  |         |
| <a id="js_proto-bin"></a>bin         | -                              | <a href="https://bazel.build/docs/build-ref.html#labels">Label</a> | required  |         |
| <a id="js_proto-runtime"></a>runtime | -                              | <a href="https://bazel.build/docs/build-ref.html#labels">Label</a> | required  |         |

<a id="#js_proto_library"></a>

## js_proto_library

<pre>
js_proto_library(<a href="#js_proto_library-name">name</a>, <a href="#js_proto_library-deps">deps</a>, <a href="#js_proto_library-js_proto">js_proto</a>, <a href="#js_proto_library-output">output</a>, <a href="#js_proto_library-root">root</a>)
</pre>

**ATTRIBUTES**

| Name                                           | Description                    | Type                                                                        | Mandatory | Default |
| :--------------------------------------------- | :----------------------------- | :-------------------------------------------------------------------------- | :-------- | :------ |
| <a id="js_proto_library-name"></a>name         | A unique name for this target. | <a href="https://bazel.build/docs/build-ref.html#name">Name</a>             | required  |         |
| <a id="js_proto_library-deps"></a>deps         | Protobufs                      | <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a> | required  |         |
| <a id="js_proto_library-js_proto"></a>js_proto | Config                         | <a href="https://bazel.build/docs/build-ref.html#labels">Label</a>          | required  |         |
| <a id="js_proto_library-output"></a>output     | -                              | <a href="https://bazel.build/docs/build-ref.html#labels">Label</a>          | required  |         |
| <a id="js_proto_library-root"></a>root         | CommonJS root                  | <a href="https://bazel.build/docs/build-ref.html#labels">Label</a>          | required  |         |

<a id="#configure_js_proto"></a>

## configure_js_proto

<pre>
configure_js_proto(<a href="#configure_js_proto-name">name</a>, <a href="#configure_js_proto-dep">dep</a>, <a href="#configure_js_proto-visibility">visibility</a>)
</pre>

**PARAMETERS**

| Name                                                 | Description               | Default Value     |
| :--------------------------------------------------- | :------------------------ | :---------------- |
| <a id="configure_js_proto-name"></a>name             | <p align="center"> - </p> | none              |
| <a id="configure_js_proto-dep"></a>dep               | <p align="center"> - </p> | none              |
| <a id="configure_js_proto-visibility"></a>visibility | <p align="center"> - </p> | <code>None</code> |
