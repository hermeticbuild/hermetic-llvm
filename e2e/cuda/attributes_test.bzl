"""Checks that CUDA compilation honors disabled features in both passes."""

load("@bazel_skylib//lib:unittest.bzl", "analysistest", "asserts")
load("@rules_cc//cc:defs.bzl", "CcInfo")

def _disabled_dbg_test_impl(ctx):
    env = analysistest.begin(ctx)
    compiles = [a for a in analysistest.target_actions(env) if a.mnemonic == "CppCompile"]
    asserts.true(env, len(compiles) > 0, "Expected a source compilation action")
    for action in compiles:
        asserts.false(env, "-g" in action.argv, "features = ['-dbg'] must disable debug info")
    return analysistest.end(env)

host_features_test = analysistest.make(
    _disabled_dbg_test_impl,
    config_settings = {"//command_line_option:compilation_mode": "dbg"},
)

device_features_test = analysistest.make(
    _disabled_dbg_test_impl,
    config_settings = {
        "//command_line_option:compilation_mode": "dbg",
        str(Label("@llvm//config:cuda_device_mode")): True,
        str(Label("@llvm//config:nvidia_compute_capability")): "sm_120",
    },
)

def _fatbinary_inputs_test_impl(ctx):
    env = analysistest.begin(ctx)
    actions = [a for a in analysistest.target_actions(env) if a.mnemonic == "CudaFatbin"]
    asserts.equals(env, 1, len(actions))
    for action in actions:
        images = [arg for arg in action.argv if arg.startswith("--image3=")]
        asserts.equals(env, 2, len(images), "One independently compiled cubin per SM")
        for sm in ["80", "120"]:
            matches = [arg for arg in images if arg.startswith("--image3=kind=elf,sm=%s," % sm)]
            asserts.equals(env, 1, len(matches))
        objects = [f for f in action.inputs.to_list() if f.extension == "o"]
        asserts.equals(env, 2, len(objects), "Transitive objects must not enter the fatbinary")
        for obj in objects:
            asserts.equals(env, "attribute_test.pic.o", obj.basename)
    return analysistest.end(env)

fatbinary_inputs_test = analysistest.make(_fatbinary_inputs_test_impl)

def _device_policy_test_impl(ctx):
    env = analysistest.begin(ctx)
    compiles = [a for a in analysistest.target_actions(env) if a.mnemonic == "CppCompile"]
    asserts.true(env, len(compiles) > 0)
    for action in compiles:
        asserts.true(env, "--offload-device-only" in action.argv)
        asserts.false(env, any([arg.startswith("-flto") for arg in action.argv]), "CPU ThinLTO must not replace cubins with LLVM bitcode")
    return analysistest.end(env)

device_policy_test = analysistest.make(
    _device_policy_test_impl,
    config_settings = {
        "//command_line_option:features": ["thin_lto"],
        str(Label("@llvm//config:cuda_device_mode")): True,
        str(Label("@llvm//config:nvidia_compute_capability")): "sm_120",
    },
)

def _host_decoupling_test_impl(ctx):
    env = analysistest.begin(ctx)
    compiles = [a for a in analysistest.target_actions(env) if a.mnemonic == "CppCompile"]
    asserts.true(env, len(compiles) > 0)
    for action in compiles:
        asserts.true(env, "--offload-host-only" in action.argv)
        asserts.false(env, any([arg.startswith("-flto") for arg in action.argv]))
        images = [f.basename for f in action.inputs.to_list() if f.extension == "fatbin"]
        asserts.equals(env, ["empty.fatbin"], images, "Host compilation must not depend on a real image")
    return analysistest.end(env)

host_decoupling_test = analysistest.make(
    _host_decoupling_test_impl,
    config_settings = {"//command_line_option:features": ["thin_lto"]},
)

def _redirect_inputs_test_impl(ctx):
    env = analysistest.begin(ctx)
    actions = [a for a in analysistest.target_actions(env) if a.mnemonic == "CudaHostRedirect"]
    asserts.true(env, len(actions) > 0)
    for action in actions:
        objects = [f for f in action.inputs.to_list() if f.extension == "o"]
        images = [f for f in action.inputs.to_list() if f.extension == "fatbin"]
        asserts.equals(env, 1, len(objects), "Only the TU's own object is rewritten")
        asserts.equals(env, [], images, "Postprocessing must not depend on the image")
    return analysistest.end(env)

redirect_inputs_test = analysistest.make(_redirect_inputs_test_impl)

def _host_linking_test_impl(ctx):
    env = analysistest.begin(ctx)
    target = analysistest.target_under_test(env)
    for linker_input in target[CcInfo].linking_context.linker_inputs.to_list():
        asserts.false(env, linker_input.owner.name.endswith("_raw"), "Raw host archives must not reach the link")
    actions = [a for a in analysistest.target_actions(env) if a.mnemonic == "CppCompile"]
    asserts.true(env, len(actions) > 0)
    for action in actions:
        images = [f.basename for f in action.inputs.to_list() if f.extension == "fatbin"]
        asserts.equals(env, ["attribute_cuda__fatbin_0.fatbin"], images)
    return analysistest.end(env)

host_linking_test = analysistest.make(_host_linking_test_impl)
