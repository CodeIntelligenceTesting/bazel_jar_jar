# This is the provider we pass up along to the outer thin_jar_jar rule.
ShadedJars = provider(fields = [
    "java_info",
    "output_files",
])

def merge_shaded_jars_info(shaded_jars):
    return ShadedJars(
        output_files = depset(transitive = [s.output_files for s in shaded_jars]),
        java_info = java_common.make_non_strict(java_common.merge([s.java_info for s in shaded_jars])),
    )

# To name the files in a helpful manner
# we strip off from the last '.' and will then append '-shaded.jar'
def __get_no_ext_name(jar_path):
    fname = jar_path.basename
    last_indx = fname.rindex(".")
    if last_indx <= 0:
        return fname
    else:
        return fname[:last_indx]

def _jar_jar_aspect_impl(target, ctx):
    current_jars = target[JavaInfo].runtime_output_jars
    toolchain_cfg = ctx.toolchains["@com_github_johnynek_bazel_jar_jar//toolchains:toolchain_type"]
    rules = toolchain_cfg.rules.files.to_list()[0]
    duplicate_to_warn = toolchain_cfg.duplicate_class_to_warn
    # if len(current_jars) == 0:
    # print(ctx.rule.kind)
    # print(ctx.rule)
    java_outputs = []
    output_files = []
    for input_jar in current_jars:
        output_file_name = "{prefix}-shaded.jar".format(prefix = __get_no_ext_name(input_jar))
        output_file = ctx.actions.declare_file(output_file_name)
        output_files.append(output_file)
        java_outputs.append(
            JavaInfo(
                output_jar = output_file,
                compile_jar = output_file,
                deps = [d[ShadedJars].java_info for d in ctx.rule.attr.deps],
                runtime_deps = [d[ShadedJars].java_info for d in ctx.rule.attr.runtime_deps],
                exports = [d[ShadedJars].java_info for d in ctx.rule.attr.exports],
            ),
        )
        ctx.actions.run(
            inputs = [rules, input_jar],
            outputs = [output_file],
            executable = toolchain_cfg.jar_jar_runner.files_to_run,
            progress_message = "thin jarjar %s" % ctx.label,
            arguments = ["--jvm_flag=-DduplicateClassToWarn={duplicate_to_warn}".format(duplicate_to_warn=duplicate_to_warn), "process", rules.path, input_jar.path, output_file.path],
        )

    # this_shaded =
    # children = [this_shaded]
    # if "exports" in dir(ctx.rule.attr) and len(ctx.rule.attr.exports) > 0:
    #     print(ctx.rule.attr.exports)
    # #     children.append(merge_shaded_jars_info([d[ShadedJars] for d in ctx.rule.attr.exports]))
    # if "deps" in dir(ctx.rule.attr):
    #     children.append(merge_shaded_jars_info([d[ShadedJars] for d in ctx.rule.attr.deps]))
    # if "runtime_deps" in dir(ctx.rule.attr):
    #     children.append(merge_shaded_jars_info([d[ShadedJars] for d in ctx.rule.attr.runtime_deps]))

    return [
        ShadedJars(
            java_info = java_common.make_non_strict(java_common.merge(java_outputs)),
            output_files = depset(output_files),
        ),
    ]

jar_jar_aspect = aspect(
    implementation = _jar_jar_aspect_impl,
    attr_aspects = ["deps", "runtime_deps", "exports"],
    required_aspect_providers = [
        [JavaInfo],
        [ShadedJars],
    ],
    attrs = {
        "_java_toolchain": attr.label(
            default = Label("@bazel_tools//tools/jdk:current_java_toolchain"),
        ),
    },
    toolchains = [
        "@com_github_johnynek_bazel_jar_jar//toolchains:toolchain_type",
    ],
)
