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
# limitations under the License.



file(GLOB_RECURSE FBS_FILES "${SCHEMA_DIR}/*.fbs")

if(NOT FBS_FILES)
    message(WARNING "[LiteRTLM] No .fbs files found in ${SCHEMA_DIR}")
    return()
endif()

foreach(FBS_FILE ${FBS_FILES})
    get_filename_component(FBS_DIR "${FBS_FILE}" DIRECTORY)
    # Retry to absorb build-graph races where flatc or the .fbs aren't ready.
    set(RET_CODE 1)
    foreach(_attempt RANGE 1 5)
        execute_process(
            COMMAND ${FLATC_BIN} --cpp --gen-object-api --reflect-names --gen-mutable -o "${FBS_DIR}" "${FBS_FILE}"
            RESULT_VARIABLE RET_CODE
            OUTPUT_VARIABLE _flatc_out
            ERROR_VARIABLE _flatc_err
        )
        if(RET_CODE EQUAL 0)
            break()
        endif()
        message(WARNING "[LiteRTLM] flatc attempt ${_attempt} failed (code ${RET_CODE}) on ${FBS_FILE}:\n${_flatc_out}\n${_flatc_err}")
        execute_process(COMMAND ${CMAKE_COMMAND} -E sleep 2)
    endforeach()

    if(NOT RET_CODE EQUAL 0)
        message(FATAL_ERROR "Failed to compile ${FBS_FILE}\nstdout:\n${_flatc_out}\nstderr:\n${_flatc_err}")
    endif()
endforeach()