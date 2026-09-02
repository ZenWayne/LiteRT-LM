# Copyright 2026 Google LLC.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.# protobuf_patcher.cmake

include("${LITERTLM_MODULES_DIR}/utils.cmake")
include("${LITERTLM_PROTOBUF_CONFIG_PATH}")
include("${LITERTLM_ABSL_CONFIG_PATH}")

message(STATUS "[LiteRTLM] Patching Protobuf...")

set(ROOT_LIST "${LITERTLM_PROTOBUF_SRC_DIR}/CMakeLists.txt")
if(EXISTS "${ROOT_LIST}")
    file(READ "${ROOT_LIST}" CONTENT)
    string(REPLACE "project(protobuf C CXX)"
               "project(protobuf C CXX)\ninclude(${LITERTLM_PROTOBUF_SHIM_PATH})"
               CONTENT "${CONTENT}")
    file(WRITE "${ROOT_LIST}" "${CONTENT}")
else()
    message(FATAL_ERROR "Could not find Protobuf root CMakeLists.txt at ${ROOT_LIST}")
endif()

patch_file_content("${ROOT_LIST}" 
    "include\(\${protobuf_SOURCE_DIR}/cmake/abseil-cpp.cmake\)"
    "#include(${protobuf_SOURCE_DIR}/cmake/abseil-cpp.cmake)"
    False
)
file(REMOVE_RECURSE "${LITERTLM_PROTOBUF_SRC_DIR}/cmake/abseil-cpp")


set(_proto_cmake_files
    "cmake/libupb.cmake"
    "cmake/libprotoc.cmake"
    "cmake/libprotobuf.cmake"
    "cmake/libprotobuf-lite.cmake"
)

foreach(_file IN LISTS _proto_cmake_files)
    set(_path "${LITERTLM_PROTOBUF_SRC_DIR}/${_file}")
    if(EXISTS "${_path}")
        message(STATUS "[LiteRTLM] Patching visibility in ${_file}")
        file(READ "${_path}" _content)
        string(REPLACE "CXX_VISIBILITY_PRESET hidden"
            "CXX_VISIBILITY_PRESET default" _content "${_content}")
        string(REPLACE "VISIBILITY_INLINES_HIDDEN ON"
            "VISIBILITY_INLINES_HIDDEN OFF" _content "${_content}")
        file(WRITE "${_path}" "${_content}")
    endif()
endforeach()


file(GLOB_RECURSE ALL_CMAKELISTS 
    "${LITERTLM_PROTOBUF_SRC_DIR}/../*.cmake" 
    "${LITERTLM_PROTOBUF_SRC_DIR}/../**/CMakeLists.txt")

foreach(C_FILE ${ALL_CMAKELISTS})
    if("${C_FILE}" STREQUAL "${ROOT_LIST}")
        continue()
    endif()
    patch_file_content("${C_FILE}"
        "absl::[a-zA-Z0-9_]+" 
        "LiteRTLM::absl::shim" 
        TRUE
    )
    patch_file_content("${C_FILE}"
        "\${protobuf_ABSL_USED_TARGETS}" 
        " " 
        FALSE
    )
endforeach()

set(UTF8_RANGE_LIST "${LITERTLM_PROTOBUF_SRC_DIR}/third_party/utf8_range/CMakeLists.txt")
patch_file_content("${UTF8_RANGE_LIST}" 
    "project (utf8_range C CXX)"
    "project (utf8_range C CXX)\n
    include(${LITERTLM_MODULES_DIR}/utils.cmake)\n
    include(${LITERTLM_PROTOBUF_CONFIG_PATH})\n
    include(${LITERTLM_ABSL_CONFIG_PATH})\n
    include(${LITERTLM_ABSL_AGGREGATE_PATH})\n"
    FALSE
)

# [LiteRTLM] P8 (see docs/arm64-90f42140-rebuild-handoff.md): the
# protoc-gen-upb* executables fail to link in the CROSS (litert_lm) build (the
# fork's absl delivery does not reach their link line - broad absl:: undefined
# symbols) and they are host-only codegen tools: unusable as arm64 artifacts
# and nothing in the cross build consumes them (sentencepiece/tflite generate
# with the host protoc). Drop the generator targets by commenting out their
# include - cross phase ONLY. The prebuild (host) phase keeps them: the host
# protobuf build must also produce protoc (PROTOC_BINARIES=ON there) and its
# install.cmake's generator install block references those targets.
# libupb itself stays (libprotoc requires it) and install.cmake is left
# untouched: in the cross phase the generator install/export rules live under
# if(protobuf_BUILD_PROTOC_BINARIES), which is OFF via protobuf.cmake, so no
# dangling install/export targets are generated while the library list (incl.
# libupb) stays intact.
if("${LITERTLM_ORCHESTRATION_PHASE}" STREQUAL "litert_lm")
    patch_file_content("${ROOT_LIST}"
        "include\(\$\{protobuf_SOURCE_DIR}/cmake/upb_generators.cmake\)"
        "#include(${protobuf_SOURCE_DIR}/cmake/upb_generators.cmake)"
        False
    )
endif()
