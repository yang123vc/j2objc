#!/bin/bash
# Copyright 2011 Google Inc.  All Rights Reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
# A convenience wrapper for compiling files translated by j2objc using Clang.
# The JRE emulation and proto wrapper library include and library paths are
# added, as well as standard Clang flags for compiling and linking Objective-C
# applications on iOS.
#
# Usage:
#   j2objcc <clang options> <files>
#

declare RAW_ARGS="$@"

if [ -L "$0" ]; then
  readonly DIR=$(dirname $(readlink "$0"))
else
  readonly DIR=$(dirname "$0")
fi

if [ "x${PUBLIC_HEADERS_FOLDER_PATH}" != "x" ]; then
	readonly INCLUDE_PATH=${DIR}/${PUBLIC_HEADERS_FOLDER_PATH}
elif [ -d ${DIR}/include ]; then
  readonly INCLUDE_PATH=${DIR}/include
else
	# Xcode 4 default for new projects.
  readonly INCLUDE_PATH=${DIR}/Headers
fi

declare FRAMEWORKS="-framework Foundation -framework Security"
if [ "x${IPHONEOS_DEPLOYMENT_TARGET}" = "x" ]; then
  FRAMEWORKS="${FRAMEWORKS} -framework ExceptionHandling"
fi

# Default set of warnings to suppress. To enable any of these, specify
# the flag without "no-" after all the other command-line arguments.
declare NO_WARNINGS="-Wno-parentheses"
NO_WARNINGS="${NO_WARNINGS} -fno-strict-overflow"
NO_WARNINGS="${NO_WARNINGS} -Wno-compare-distinct-pointer-types"
NO_WARNINGS="${NO_WARNINGS} -Wno-nullability-completeness"

declare CC_FLAGS="-fobjc-weak -Werror ${NO_WARNINGS}"
declare OTHER_LIBS="-l iconv -l z -l j2objc_main -l c++"
declare SYSROOT_PATH="none"
declare EMUL_LIB="-ljre_emul"
declare LINK_FLAGS=""
declare DO_LINK="yes"
declare USE_ARC="no"
declare OBJC_CPP="no"
declare CORE_LIB_WARNING="warning: linking the core runtime to reduce binary \
size. Use -ljre_emul to link the full Java runtime."

while [ $# -gt 0 ]; do
  case $1 in
    # Check whether linking is disabled by a -c, -S, or -E option.
    -[cSE]) DO_LINK="no" ;;
    -fobjc-arc) USE_ARC="yes" ;;
    # Check whether we need to build for C++ instead of C.
    -x) if [ "$2" == "objective-c++" ]; then OBJ_CPP="yes"; fi; shift ;;
    *.mm) OBJC_CPP="yes";;
    # Save sysroot path for later inspection.
    -isysroot) SYSROOT_PATH="$2"; shift ;;
    -ObjC) EMUL_LIB="-ljre_core" ;;
    --std=*) LANG_STANDARD=${1:6} ;;
  esac
  shift
done

# If --std= flag isn't specified, use the latest language standard.
if [[ x"$LANG_STANDARD" == "x" ]]; then
  if [[ "$OBJC_CPP" == "yes" ]]; then
    CC_FLAGS="$CC_FLAGS --std=c++17"
  else
    CC_FLAGS="$CC_FLAGS --std=c17"
  fi
fi

if [[ "$USE_ARC" == "yes" ]]; then
  CC_FLAGS="$CC_FLAGS -fobjc-arc-exceptions"
fi

if [[ $RAW_ARGS =~ .*-l(\ )*jre_emul\ .* ]]; then
  EMUL_LIB=""
fi

if [[ "$DO_LINK" == "yes" ]]; then
  if [[ "$SYSROOT_PATH" == "none" || "$SYSROOT_PATH" == *"MacOSX"* ]]; then
    readonly LIB_PATH=${DIR}/lib/macosx
  else
    readonly LIB_PATH=${DIR}/lib
  fi
  if [[ "$EMUL_LIB" == "-ljre_core" ]]; then
    >&2 echo "$CORE_LIB_WARNING";
  fi
  LINK_FLAGS="${EMUL_LIB} ${OTHER_LIBS} ${FRAMEWORKS} -L ${LIB_PATH}"
fi

xcrun clang ${RAW_ARGS} -I ${INCLUDE_PATH} ${CC_FLAGS} ${LINK_FLAGS}
