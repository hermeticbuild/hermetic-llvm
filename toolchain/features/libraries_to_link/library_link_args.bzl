# Copyright 2024 The Bazel Authors. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
"""Helper macros for declaring library link arguments."""

load("@rules_cc//cc/toolchains:nested_args.bzl", "cc_nested_args")

def apple_force_load_library_args(name, variable):
    """Declares -force_load argument expansion for a library."""
    cc_nested_args(
        name = name,
        nested = [
            ":{}_force_load_library".format(name),
            ":{}_no_force_load_library".format(name),
        ],
    )
    cc_nested_args(
        name = name + "_no_force_load_library",
        args = ["{library}"],
        format = {
            "library": variable,
        },
        requires_false = "@rules_cc//cc/toolchains/variables:libraries_to_link.is_whole_archive",
    )
    cc_nested_args(
        name = name + "_force_load_library",
        args = ["-Wl,-force_load,{library}"],
        format = {
            "library": variable,
        },
        requires_true = "@rules_cc//cc/toolchains/variables:libraries_to_link.is_whole_archive",
    )

def library_link_args(name, library_type, from_variable, iterate_over_variable = False):
    """Declares arguments for one libraries_to_link entry type."""
    native.alias(
        name = name,
        actual = select({
            "@rules_cc//cc/settings:apple_constraint": ":apple_{}".format(name),
            "//conditions:default": ":generic_{}".format(name),
        }),
    )
    cc_nested_args(
        name = "generic_{}".format(name),
        args = ["{library}"],
        format = {
            "library": from_variable,
        },
        iterate_over = from_variable if iterate_over_variable else None,
        requires_equal = "@rules_cc//cc/toolchains/variables:libraries_to_link.type",
        requires_equal_value = library_type,
    )
    cc_nested_args(
        name = "apple_{}".format(name),
        iterate_over = from_variable if iterate_over_variable else None,
        nested = [":{}_maybe_force_load".format(name)],
        requires_equal = "@rules_cc//cc/toolchains/variables:libraries_to_link.type",
        requires_equal_value = library_type,
    )
    apple_force_load_library_args(
        name = "{}_maybe_force_load".format(name),
        variable = from_variable,
    )
