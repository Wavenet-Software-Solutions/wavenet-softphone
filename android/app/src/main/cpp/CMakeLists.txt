cmake_minimum_required(VERSION 3.10.2)
project(pjsip_shim)

# Build a shared lib for JNI
add_library(pjsip_shim SHARED pjsip_shim.cpp)

# 💙 Path to prebuilt PJSIP (arm64)
set(PJ_DIR "${CMAKE_CURRENT_LIST_DIR}/../../../../third_party/pjsip/arm64")
message(STATUS "💙 Using PJ_DIR=${PJ_DIR}")

function(find_lib out_var base)
    if(EXISTS "${PJ_DIR}/${base}-arm64-android.a")
        set(${out_var} "${PJ_DIR}/${base}-arm64-android.a" PARENT_SCOPE)
    elseif(EXISTS "${PJ_DIR}/${base}-aarch64-unknown-linux-android.a")
        set(${out_var} "${PJ_DIR}/${base}-aarch64-unknown-linux-android.a" PARENT_SCOPE)
    elseif(EXISTS "${PJ_DIR}/../${base}-aarch64-unknown-linux-android.a")
        set(${out_var} "${PJ_DIR}/../${base}-aarch64-unknown-linux-android.a" PARENT_SCOPE)
    else()
        message(FATAL_ERROR "❌ Missing: ${base}-*.a in ${PJ_DIR} or ../lib")
    endif()
endfunction()

# === Core PJSIP libraries ===
find_lib(LIB_PJSUA2       "pjsip/lib/libpjsua2")
find_lib(LIB_PJSUA        "pjsip/lib/libpjsua")
find_lib(LIB_PJSIP_UA     "pjsip/lib/libpjsip-ua")
find_lib(LIB_PJSIP_SIMPLE "pjsip/lib/libpjsip-simple")
find_lib(LIB_PJSIP        "pjsip/lib/libpjsip")

# === PJMEDIA layer ===
find_lib(LIB_PJMEDIA_CODEC    "pjmedia/lib/libpjmedia-codec")
find_lib(LIB_PJMEDIA_AUDIODEV "pjmedia/lib/libpjmedia-audiodev")
find_lib(LIB_PJMEDIA          "pjmedia/lib/libpjmedia")
find_lib(LIB_PJMEDIA_VIDEODEV "pjmedia/lib/libpjmedia-videodev")

# === PJNATH / PJLIB-UTIL / PJLIB ===
find_lib(LIB_PJNATH      "pjnath/lib/libpjnath")
find_lib(LIB_PJLIB_UTIL  "pjlib-util/lib/libpjlib-util")
find_lib(LIB_PJ          "pjlib/lib/libpj")

# === Third-party deps (libsrtp & libresample) ===
if(EXISTS "${PJ_DIR}/third_party/lib/libsrtp-aarch64-unknown-linux-android.a")
    set(LIB_SRTP "${PJ_DIR}/third_party/lib/libsrtp-aarch64-unknown-linux-android.a")
elseif(EXISTS "${PJ_DIR}/../lib/libsrtp-aarch64-unknown-linux-android.a")
    set(LIB_SRTP "${PJ_DIR}/../lib/libsrtp-aarch64-unknown-linux-android.a")
else()
    message(WARNING "⚠️  Could not find libsrtp, SRTP will be disabled.")
endif()

if(EXISTS "${PJ_DIR}/third_party/lib/libresample-aarch64-unknown-linux-android.a")
    set(LIB_RESAMPLE "${PJ_DIR}/third_party/lib/libresample-aarch64-unknown-linux-android.a")
elseif(EXISTS "${PJ_DIR}/../lib/libresample-aarch64-unknown-linux-android.a")
    set(LIB_RESAMPLE "${PJ_DIR}/../lib/libresample-aarch64-unknown-linux-android.a")
else()
    message(WARNING "⚠️  Could not find libresample, fallback resampler may be used.")
endif()

# === Include headers ===
target_include_directories(pjsip_shim PRIVATE
        ${PJ_DIR}/pjlib/include
        ${PJ_DIR}/pjlib-util/include
        ${PJ_DIR}/pjnath/include
        ${PJ_DIR}/pjmedia/include
        ${PJ_DIR}/pjsip/include
)

# === Define endian + feature flags ===
target_compile_definitions(pjsip_shim PRIVATE
        PJ_IS_LITTLE_ENDIAN=1
        PJ_IS_BIG_ENDIAN=0
        PJMEDIA_HAS_SRTP=1
)

# Keep symbols tidy; we’ll explicitly export FFI API in code
if (CMAKE_CXX_COMPILER_ID MATCHES "Clang|GNU")
    target_compile_options(pjsip_shim PRIVATE -fvisibility=hidden -fvisibility-inlines-hidden)
endif()

# 🔁 WRAP both unique-string generators (fix Call-ID + Via branch)
# add to existing wraps
target_link_options(pjsip_shim PRIVATE
        -Wl,--wrap=pj_generate_unique_string
        -Wl,--wrap=pj_create_unique_string
        -Wl,--wrap=pj_guid_create
        -Wl,--wrap=pj_generate_unique_string2      # NEW
        -Wl,--wrap=pj_create_unique_string2        # NEW
        -Wl,--wrap=pj_create_random_string         # NEW
)
#target_link_options(pjsip_shim PRIVATE
#        -Wl,--wrap=pj_generate_unique_string
#        -Wl,--wrap=pj_create_unique_string
#        -Wl,--wrap=pj_create_random_string
#        -Wl,--wrap=pj_guid_create
#)


# === Android system libraries ===
find_library(log-lib log)
find_library(android-lib android)
find_library(dl-lib dl)
find_library(m-lib m)
find_library(z-lib z)
find_library(opensles-lib OpenSLES)

# === Link everything ===
target_link_libraries(pjsip_shim
        ${LIB_PJSUA2}
        ${LIB_PJSUA}
        ${LIB_PJSIP_UA}
        ${LIB_PJSIP_SIMPLE}
        ${LIB_PJSIP}
        ${LIB_PJMEDIA_CODEC}
        ${LIB_PJMEDIA_AUDIODEV}
        ${LIB_PJMEDIA}
        ${LIB_PJMEDIA_VIDEODEV}
        ${LIB_PJNATH}
        ${LIB_PJLIB_UTIL}
        ${LIB_PJ}
        ${LIB_SRTP}
        ${LIB_RESAMPLE}
        ${log-lib}
        ${android-lib}
        ${dl-lib}
        ${m-lib}
        ${z-lib}
        ${opensles-lib}
)

message(STATUS "✨ PJSIP SHIM configured with WRAPs (create+generate) + SRTP + libresample 💙")
