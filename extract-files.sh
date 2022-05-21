#!/bin/bash
#
# Copyright (C) 2016 The CyanogenMod Project
# Copyright (C) 2017-2020 The LineageOS Project
#
# SPDX-License-Identifier: Apache-2.0
#

set -e

DEVICE=land
VENDOR=xiaomi

# Load extract_utils and do some sanity checks
MY_DIR="${BASH_SOURCE%/*}"
if [[ ! -d "${MY_DIR}" ]]; then MY_DIR="${PWD}"; fi

ANDROID_ROOT="${MY_DIR}/../../.."

HELPER="${ANDROID_ROOT}/tools/extract-utils/extract_utils.sh"
if [ ! -f "${HELPER}" ]; then
    echo "Unable to find helper script at ${HELPER}"
    exit 1
fi
source "${HELPER}"

# Default to sanitizing the vendor folder before extraction
CLEAN_VENDOR=true

KANG=
SECTION=

while [ "${#}" -gt 0 ]; do
    case "${1}" in
        -n | --no-cleanup )
                CLEAN_VENDOR=false
                ;;
        -k | --kang )
                KANG="--kang"
                ;;
        -s | --section )
                SECTION="${2}"; shift
                CLEAN_VENDOR=false
                ;;
        * )
                SRC="${1}"
                ;;
    esac
    shift
done

if [ -z "${SRC}" ]; then
    SRC="adb"
fi

function blob_fixup() {
    case "${1}" in
        vendor/lib/libmmsw_platform.so|vendor/lib/libmmsw_detail_enhancement.so)
            "${PATCHELF}" --remove-needed "libbinder.so" "${2}"
            sed -i 's|libgui.so|libwui.so|g' "${2}"
            ;;
        vendor/lib/libmmcamera2_sensor_modules.so)
            sed -i 's|/system/etc/camera/|/vendor/etc/camera/|g' "${2}"
            sed -i 's|data/misc/camera|data/vendor/qcam|g' "${2}"
            ;;
        vendor/lib/libmmcamera_tintless_bg_pca_algo.so \
        |vendor/lib/libmmcamera_pdafcamif.so \
        |vendor/lib/libmmcamera2_dcrf.so \
        |vendor/lib/libmmcamera_imglib.so \
        |vendor/lib/libmmcamera_dbg.so \
        |vendor/lib/libmmcamera2_stats_algorithm.so \
        |vendor/lib/libmmcamera2_mct.so \
        |vendor/lib/libmmcamera_tuning.so \
        |vendor/lib/libmmcamera_tintless_algo.so \
        |vendor/lib/libmmcamera2_iface_modules.so \
        |vendor/lib/libmmcamera2_q3a_core.so \
        |vendor/lib/libmmcamera2_pproc_modules.so \
        |vendor/lib/libmmcamera2_imglib_modules.so \
        |vendor/lib/libmmcamera2_cpp_module.so \
        |vendor/lib/libmmcamera_pdaf.so)
            sed -i 's|data/misc/camera|data/vendor/qcam|g' "${2}"
            ;;
        vendor/bin/mm-qcamera-daemon)
            sed -i 's|data/misc/camera|data/vendor/qcam|g' "${2}"
            if ! "${PATCHELF}" --print-needed "${2}" | grep "libshim_pthreadts.so" >/dev/null; then
                "${PATCHELF}" --add-needed "libshim_pthreadts.so" "${2}"
            fi
            if ! "${PATCHELF}" --print-needed "${2}" | grep "libshim_mutexdestroy.so" >/dev/null; then
                "${PATCHELF}" --add-needed "libshim_mutexdestroy.so" "${2}"
            fi
            ;;
        vendor/lib/libmmcamera2_stats_modules.so)
            sed -i 's|data/misc/camera|data/vendor/qcam|g' "${2}"
            sed -i 's|libgui.so|libwui.so|g' "${2}"
            "${PATCHELF}" --replace-needed "libandroid.so" "libshims_android.so" "${2}"
            ;;
        vendor/bin/gx_fpcmd|vendor/bin/gx_fpd)
            "${PATCHELF}" --remove-needed "libbacktrace.so" "${2}"
            "${PATCHELF}" --remove-needed "libunwind.so" "${2}"
            if ! "${PATCHELF}" --print-needed "${2}" | grep "liblog.so" >/dev/null; then
                "${PATCHELF}" --add-needed "liblog.so" "${2}"
            fi
            ;;
        vendor/lib64/libfpservice.so)
            if ! "${PATCHELF}" --print-needed "${2}" | grep "libshims_binder.so" >/dev/null; then
                "${PATCHELF}" --add-needed "libshims_binder.so" "${2}"
            fi
            ;;
        vendor/lib64/hw/fingerprint.goodix.so)
            sed -i 's|libandroid_runtime.so|libshims_android.so\x00\x00|g' "${2}"
            ;;
    esac
}

    # Initialize the helper
setup_vendor "${DEVICE}" "${VENDOR}" "${ANDROID_ROOT}" false "${CLEAN_VENDOR}"

extract "${MY_DIR}/proprietary-files.txt" "${SRC}" "${KANG}" --section "${SECTION}"

"${MY_DIR}/setup-makefiles.sh"
