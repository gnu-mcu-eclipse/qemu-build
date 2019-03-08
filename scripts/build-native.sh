#!/usr/bin/env bash

# -----------------------------------------------------------------------------
# Safety settings (see https://gist.github.com/ilg-ul/383869cbb01f61a51c4d).

if [[ ! -z ${DEBUG} ]]
then
  set ${DEBUG} # Activate the expand mode if DEBUG is anything but empty.
else
  DEBUG=""
fi

set -o errexit # Exit if command failed.
set -o pipefail # Exit if pipe failed.
set -o nounset # Exit if variable not set.

# Remove the initial space and instead use '\n'.
IFS=$'\n\t'

# -----------------------------------------------------------------------------
# Identify the script location, to reach, for example, the helper scripts.

build_script_path="$0"
if [[ "${build_script_path}" != /* ]]
then
  # Make relative path absolute.
  build_script_path="$(pwd)/$0"
fi

script_folder_path="$(dirname "${build_script_path}")"
script_folder_name="$(basename "${script_folder_path}")"

# =============================================================================

# Script to build a native GNU MCU Eclipse ARM QEMU, which uses the
# tools and libraries available on the host machine. It is generally
# intended for development and creating customised versions (as opposed
# to the build intended for creating distribution packages).
#
# Developed on Ubuntu 18 LTS x64 and macOS 10.13. 

# -----------------------------------------------------------------------------

echo
echo "GNU MCU Eclipse QEMU native build script."

echo
host_functions_script_path="${script_folder_path}/helper/host-functions-source.sh"
echo "Host helper functions source script: \"${host_functions_script_path}\"."
source "${host_functions_script_path}"

host_detect

TARGET_ARCH="${HOST_NODE_ARCH}"
TARGET_PLATFORM="${HOST_NODE_PLATFORM}"

# -----------------------------------------------------------------------------

ACTION=""

DO_BUILD_WIN=""
IS_DEBUG=""
IS_DEVELOP=""
WITH_STRIP=""
IS_NATIVE="y"

# Attempts to use 8 occasionally failed, reduce if necessary.
if [ "$(uname)" == "Darwin" ]
then
  JOBS="--jobs=$(sysctl -n hw.ncpu)"
else
  JOBS="--jobs=$(grep ^processor /proc/cpuinfo|wc -l)"
fi

while [ $# -gt 0 ]
do
  case "$1" in

    clean|cleanlibs|cleanall)
      ACTION="$1"
      ;;

    --win|--windows)
      DO_BUILD_WIN="y"
      ;;

    --debug)
      IS_DEBUG="y"
      ;;

    --develop)
      IS_DEVELOP="y"
      ;;

    --jobs)
      shift
      JOBS="--jobs=$1"
      ;;

   --help)
      echo "Build a local/native GNU MCU Eclipse ARM QEMU."
      echo "Usage:"
      # Some of the options are processed by the container script.
      echo "    bash $0 [--win] [--debug] [--develop] [--jobs N] [--help] [clean|cleanlibs|cleanall]"
      echo
      exit 0
      ;;

    *)
      echo "Unknown action/option $1"
      exit 1
      ;;

  esac
  shift

done

if [ "${DO_BUILD_WIN}" == "y" ]
then
  if [ "${HOST_NODE_PLATFORM}" == "linux" ]
  then
    TARGET_PLATFORM="win32"
  else
    echo "Windows cross builds are available only on Linux."
    exit 1
  fi
fi


# -----------------------------------------------------------------------------

if [ -f "${script_folder_path}"/VERSION ]
then
  # When running from the distribution folder.
  RELEASE_VERSION=${RELEASE_VERSION:-"$(cat "${script_folder_path}"/VERSION)"}
fi

echo
echo "Processing release ${RELEASE_VERSION}..."

echo
defines_script_path="${script_folder_path}/defs-source.sh"
echo "Definitions source script: \"${defines_script_path}\"."
source "${defines_script_path}"

# -----------------------------------------------------------------------------

common_helper_functions_script_path="${script_folder_path}"/helper/common-functions-source.sh
echo "Common helper functions source script: \"${common_helper_functions_script_path}\"."
source "${common_helper_functions_script_path}"

# May override some of the helper/common definitions.
common_functions_script_path="${script_folder_path}"/common-functions-source.sh
echo "Common functions source script: \"${common_functions_script_path}\"."
source "${common_functions_script_path}"

# -----------------------------------------------------------------------------

# The Work folder is in HOME.
HOST_WORK_FOLDER_PATH="${HOST_WORK_FOLDER_PATH:-"${HOME}/Work/${APP_LC_NAME}-dev"}"
mkdir -p "${HOST_WORK_FOLDER_PATH}"

SOURCES_FOLDER_PATH="${SOURCES_FOLDER_PATH:-"${HOST_WORK_FOLDER_PATH}/sources"}"
mkdir -p "${SOURCES_FOLDER_PATH}"

host_prepare_cache
prepare_xbb_env

do_actions

# -----------------------------------------------------------------------------

common_libs_functions_script_path="${script_folder_path}/${COMMON_LIBS_FUNCTIONS_SCRIPT_NAME}"
echo "Common libs functions source script: \"${common_libs_functions_script_path}\"."
source "${common_libs_functions_script_path}"

common_app_functions_script_path="${script_folder_path}/${COMMON_APP_FUNCTIONS_SCRIPT_NAME}"
echo "Common app functions source script: \"${common_app_functions_script_path}\"."
source "${common_app_functions_script_path}"

# -----------------------------------------------------------------------------

QEMU_PROJECT_NAME="qemu"
QEMU_VERSION="2.8"

QEMU_SRC_FOLDER_NAME=${QEMU_SRC_FOLDER_NAME:-"${QEMU_PROJECT_NAME}.git"}
QEMU_GIT_URL="https://github.com/gnu-mcu-eclipse/qemu.git"

if [ "${IS_DEVELOP}" == "y" ]
then
  QEMU_GIT_BRANCH=${QEMU_GIT_BRANCH:-"gnuarmeclipse-dev"}
else
  QEMU_GIT_BRANCH=${QEMU_GIT_BRANCH:-"gnuarmeclipse"}
fi

QEMU_GIT_COMMIT=${QEMU_GIT_COMMIT:-""}

# -----------------------------------------------------------------------------

# ZLIB_VERSION="1.2.8"
ZLIB_VERSION="1.2.11"

# LIBPNG_VERSION="1.6.23"
# LIBPNG_VERSION="1.6.34"
LIBPNG_VERSION="1.6.36"
LIBPNG_SFOLDER="libpng16"

JPEG_VERSION="9b"

# SDL2_VERSION="2.0.5"
# SDL2_VERSION="2.0.8"
SDL2_VERSION="2.0.9"

# SDL2_IMAGE_VERSION="2.0.1"
# SDL2_IMAGE_VERSION="2.0.3"
SDL2_IMAGE_VERSION="2.0.4"

LIBFFI_VERSION="3.2.1"

# Fails with libtool problems.
# LIBICONV_VERSION="1.14"
LIBICONV_VERSION="1.15"

GETTEXT_VERSION="0.19.8.1"

# GLIB_MVERSION="2.51"
# GLIB_VERSION="${GLIB_MVERSION}.0"
GLIB_MVERSION="2.56"
GLIB_VERSION="${GLIB_MVERSION}.4"

# PIXMAN_VERSION="0.34.0"
PIXMAN_VERSION="0.38.0"

# LIBXML2_VERSION="2.9.8"

# -----------------------------------------------------------------------------

# Set the DISTRIBUTION_FILE_DATE.
host_get_current_date

# -----------------------------------------------------------------------------

host_start_timer

prepare_extras

APP_PREFIX="${APP_INSTALL_FOLDER_PATH}"
APP_PREFIX_DOC="${APP_PREFIX}"/doc

# -----------------------------------------------------------------------------

copy_build_git

# -----------------------------------------------------------------------------
# Build dependent libraries.

if true
then

  do_zlib

  do_libpng
  do_jpeg
  do_libiconv

  do_sdl2
  do_sdl2_image

  do_libffi

  # if [ "${TARGET_PLATFORM}" == "win32" ]
  # then
  #   do_libxml2
  # fi

  do_gettext # requires libxml2 on windows
  do_glib
  do_pixman

fi

# -----------------------------------------------------------------------------

do_qemu

# -----------------------------------------------------------------------------

host_stop_timer

# Completed successfully.
exit 0

# -----------------------------------------------------------------------------
