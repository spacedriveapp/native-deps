#!/usr/bin/env bash

set -euo pipefail

OS_IPHONE=${OS_IPHONE:-0}

case "${TARGET:?TARGET envvar is required to be defined}" in
  x86_64-linux-musl | aarch64-linux-musl) ;;
  x86_64-linux-gnu* | aarch64-linux-gnu*)
    # Set the glibc minimum version, RHEL-7.9 and CentOS 7
    TARGET="${TARGET%%.*}.2.17"
    ;;
  x86_64-darwin-apple | x86_64-apple-darwin-macho)
    if [ "$OS_IPHONE" -eq 1 ]; then
      export SDKROOT="${IOS_SDKROOT:?Missing iOS SDK}"
    elif [ "$OS_IPHONE" -eq 2 ]; then
      export SDKROOT="${IOS_SIMULATOR_SDKROOT:?Missing iOS simulator SDK}"
    else
      export SDKROOT="${MACOS_SDKROOT:?Missing macOS SDK}"
    fi
    TARGET="x86_64-apple-darwin-macho"
    ;;
  aarch64-darwin-apple | arm64-apple-darwin-macho)
    if [ "$OS_IPHONE" -eq 1 ]; then
      export SDKROOT="${IOS_SDKROOT:?Missing iOS SDK}"
    elif [ "$OS_IPHONE" -eq 2 ]; then
      export SDKROOT="${IOS_SIMULATOR_SDKROOT:?Missing iOS simulator SDK}"
    else
      export SDKROOT="${MACOS_SDKROOT:?Missing macOS SDK}"
    fi
    TARGET="arm64-apple-darwin-macho"
    ;;
  x86_64-windows-gnu | aarch64-windows-gnu) ;;
  *)
    echo "Unsupported target: $TARGET" >&2
    exit 1
    ;;
esac

is_cpp=0
case "$(basename "$0")" in
  cc)
    case "$TARGET" in
      *darwin*)
        # Use clang instead of zig for darwin targets
        CMD='clang-18'
        ;;
      *) CMD='zig cc' ;;
    esac
    ;;
  c++)
    is_cpp=1
    case "$TARGET" in
      *darwin*)
        # Use clang instead of zig for darwin targets
        CMD='clang++-18'
        ;;
      *) CMD='zig c++' ;;
    esac
    ;;
  *)
    echo "Unsupported mode: $(basename "$0")" >&2
    exit 1
    ;;
esac

args_bak=("$@")

lto=''
argv=()
stdin=0
stdout=0
l_args=()
c_argv=('-target' "$TARGET")
sysroot=''
assembler=0
os_iphone="${OS_IPHONE:-0}"
preprocessor=0
cpu_features=()
assembler_file=0
should_add_libcharset=0
has_undefined_dynamic_lookup=0
while [ "$#" -gt 0 ]; do
  # Grab linker args into a separate array
  if (case "$1" in -Wl,*) exit 0 ;; *) exit 1 ;; esac) then
    IFS=',' read -ra _args <<<"$1"
    unset "_args[0]"
    l_args+=("${_args[@]}")
    shift
    continue
  fi

  if [ "$1" = '-Xlinker' ] || [ "$1" = '--for-linker' ]; then
    l_args+=("${2:?Linker argument not passed}")
    shift 2
    continue
  elif (case "$1" in --for-linker=*) exit 0 ;; *) exit 1 ;; esac) then
    l_args+=("${1#*=}")
    shift
    continue
  elif [ "$1" = '-o-' ] || [ "$1" = '-o=-' ]; then
    # -E redirect to stdout by default, -o - breaks it so we ignore it
    stdout=1
  elif [ "$1" = '-o' ] && [ "${2:-}" = '-' ]; then
    stdout=1
    shift 2
    continue
  elif [ "$1" = '-g' ] || [ "$1" = '-gfull' ] || [ "$1" = '--debug' ]; then
    true
  elif (case "$1" in --debug=* | -gdwarf*) exit 0 ;; *) exit 1 ;; esac) then
    true
  elif [ "$1" = '-' ]; then
    stdin=1
  elif [ "$1" = '-lgcc_s' ]; then
    # Replace libgcc_s with libunwind
    argv+=('-lunwind')
  elif [ "$1" == '-lgcc_eh' ]; then
    # zig doesn't provide gcc_eh alternative
    # https://github.com/ziglang/zig/issues/17268
    # We use libc++ to replace it
    argv+=('-lc++')
  elif [ "$1" = '-fno-lto' ]; then
    # Zig dont respect -fno-lto when -flto is set, so keep track of it here and strip it if needed
    lto='-fno-lto'
  elif [ "$1" = '-flto' ]; then
    if [ -z "$lto" ]; then
      lto="-flto=auto"
    fi
  elif (case "$1" in -flto=*) exit 0 ;; *) exit 1 ;; esac) then
    if [ "$lto" != '-fno-lto' ]; then
      lto="$1"
    fi
  elif [ "$1" = '-target' ]; then
    shift 2
    continue
  elif (case "$1" in --target=*) exit 0 ;; *) exit 1 ;; esac) then
    true
  elif (case "$1" in -O* | --optimize*) exit 0 ;; *) exit 1 ;; esac) then
    # Drop optmize flags, we force -Os below
    # This also misteriosly fix an aarch64 compiler bug in clang 16
    # https://github.com/llvm/llvm-project/issues/47432
    # https://github.com/llvm/llvm-project/issues/66912
    true
  elif [ "$1" = '-xassembler' ] || [ "$1" = '-Xassembler' ] || [ "$1" = '--language=assembler' ]; then
    # Zig behaves very oddly when passed the explicit assembler language option
    # https://github.com/ziglang/zig/issues/10915
    # https://github.com/ziglang/zig/pull/13544
    assembler=1
  elif { [ "$1" = '-x' ] || [ "$1" = '--language' ]; } && [ "${2:-}" = 'assembler' ]; then
    assembler=1
    shift 2
    continue
  elif (case "$1" in -mcpu=* | -march=*) exit 0 ;; *) exit 1 ;; esac) then
    # Save each feature to the cpu_features array
    IFS='+' read -ra _features <<<"$1"
    unset "_features[0]"
    cpu_features+=("${_features[@]}")
    true
  else
    case "$TARGET" in
      *darwin*)
        if [ "$1" = '-arch=aarch64' ]; then
          # macOS uses arm64 instead of aarch64
          argv+=('-arch=arm64')
        elif [ "$1" = '-arch' ] && [ "${2:-}" = 'aarch64' ]; then
          argv+=('-arch' 'arm64')
          shift 2
          continue
        elif (case "$1" in -DTARGET_OS_IPHONE*) exit 0 ;; *) exit 1 ;; esac) then
          if [ "$os_iphone" -lt 1 ]; then
            os_iphone=1
          fi
        elif (case "$1" in -DTARGET_OS_SIMULATOR*) exit 0 ;; *) exit 1 ;; esac) then
          os_iphone=2
        else
          argv+=("$1")

          # See https://github.com/apple-oss-distributions/libiconv/blob/a167071/xcodeconfig/libiconv.xcconfig
          if [ "$1" = '-lcharset' ]; then
            should_add_libcharset=-1
          elif [ "$1" = '-liconv' ] && [ "$should_add_libcharset" -eq 0 ]; then
            should_add_libcharset=1
          fi
        fi
        ;;
      *windows*)
        if (case "$1" in *.rlib | *libcompiler_builtins-*) exit 0 ;; *) exit 1 ;; esac) then
          # compiler-builtins is duplicated with zig's compiler-rt
          case "$CMD" in
            clang*) argv+=("$1") ;;
          esac
        else
          argv+=("$1")
        fi
        ;;
      *)
        argv+=("$1")
        ;;
    esac
  fi

  if [ "$1" = '-E' ]; then
    preprocessor=1
  elif [ "$1" = '--help' ] || [ "$1" = '--version' ]; then
    exec $CMD "${c_argv[@]}" "$1"
  elif (case "$1" in *.S) exit 0 ;; *) exit 1 ;; esac) then
    assembler_file=1
  elif [ "$1" = '-undefined' ] && [ "${2:-}" == 'dynamic_lookup' ]; then
    argv+=("$2")
    has_undefined_dynamic_lookup=1
    shift
  elif [ "$1" = '--sysroot' ]; then
    sysroot="${2:?Sysroot argument not passed}"
    shift
  elif (case "$1" in --sysroot=*) exit 0 ;; *) exit 1 ;; esac) then
    sysroot="$(echo "$1" | cut -d "=" -f 2-)"
  fi

  shift
done

# Ensure compiler informs linker about how to handle undefined symbols
if [ $has_undefined_dynamic_lookup -eq 1 ]; then
  l_args+=('-undefined=dynamic_lookup')
fi

# Set linker flags as global args to be parsed below
set -- "${l_args[@]}"

l_args=()
while [ "$#" -gt 0 ]; do
  if [ "$1" = '-h' ] || [ "$1" = '-help' ] || [ "$1" = '--help' ] || [ "$1" = '/?' ]; then
    case "$TARGET" in
      *linux*)
        exec zig ld.lld --help
        ;;
      *windows*)
        exec zig lld-link -help
        ;;
      *darwin*)
        exec $CMD "${c_argv[@]}" -Wl,--help
        ;;
    esac
  elif [ "$1" = '-v' ]; then
    case "$CMD" in
      clang*)
        l_args+=(-v)
        ;;
      *)
        # Verbose (Linker doesn't support flag, but compiler does, so just redirect it)
        argv+=(-v)
        ;;
    esac
  elif [ "$1" = '-Bdynamic' ]; then
    case "$CMD" in
      clang*)
        l_args+=(-Bdynamic)
        ;;
      *)
        # https://github.com/ziglang/zig/pull/16058
        # zig changes the linker behavior, -Bdynamic won't search *.a for mingw, but this may be fixed in the later version
        # here is a workaround to replace the linker switch with -search_paths_first, which will search for *.dll,*lib first,
        # then fallback to *.a
        l_args+=(-search_paths_first)
        ;;
    esac
  elif [ "$1" = '-dynamic' ]; then
    case "$CMD" in
      clang*)
        l_args+=(-dynamic)
        ;;
      *)
        # Verbose (Linker doesn't support flag, but compiler does, so just redirect it)
        argv+=(-dynamic)
        ;;
    esac
  elif [ "$1" = '-rpath-link' ]; then
    case "$CMD" in
      clang*)
        l_args+=("$1" "${2:?rpath-link requires an argument}")
        ;;
    esac

    # zig doesn't support -rpath-link arg
    # https://github.com/ziglang/zig/pull/10948
    shift
  elif [ "$1" = '-pie' ] \
    || [ "$1" = '--pic-executable' ]; then
    case "$CMD" in
      clang*)
        l_args+=(-pie)
        ;;
      *)
        # zig cc doesn't support -Wl,-pie or -Wl,--pic-executable, so we add -fPIE instead
        argv+=('-fPIE')
        ;;
    esac
  elif [ "$1" = '-dylib' ] \
    || [ "$1" = '--dynamicbase' ] \
    || [ "$1" = '--large-address-aware' ] \
    || [ "$1" = '--disable-auto-image-base' ]; then
    # zig doesn't support -dylib, --dynamicbase, --large-address-aware and --disable-auto-image-base
    # https://github.com/rust-cross/cargo-zigbuild/blob/841df510dff8c585690e85354998bbcb6695460f/src/zig.rs#L187-L190
    # https://github.com/ziglang/zig/issues/10336
    case "$CMD" in
      clang*)
        l_args+=("$1")
        ;;
    esac
  elif [ "$1" = '-exported_symbols_list' ]; then
    case "$CMD" in
      clang*)
        l_args+=("$1" "${2:?exported_symbols_list requires an argument}")
        ;;
    esac

    # zig doesn't support -exported_symbols_list arg
    # https://clang.llvm.org/docs/ClangCommandLineReference.html#cmdoption-clang-exported_symbols_list
    shift
  elif (case "$1" in --exported_symbols_list*) exit 0 ;; *) exit 1 ;; esac) then
    case "$CMD" in
      clang*)
        l_args+=("$1")
        ;;
    esac
  elif (case "$1" in --version-script=*) exit 0 ;; *) exit 1 ;; esac) then
    # Zig only support --version-script with a separate argument
    l_args+=(--version-script "${1#*=}")
  else
    l_args+=("$1")
  fi

  shift
done

if [ $stdout -eq 1 ] && ! [ $preprocessor -eq 1 ]; then
  echo "stdout mode is only supported for preprocessor" >&2
  exit 1
fi

# Work-around Zig not respecting -fno-lto when -flto is set
if [ "${LTO:-1}" -eq 0 ]; then
  argv+=('-fno-lto')
elif [ -n "$lto" ]; then
  argv+=("$lto")
fi

# Macos requires -lcharset to be defined when using -liconv
if [ $should_add_libcharset -eq 1 ]; then
  argv+=('-lcharset')
fi

# Compiler specific flags
features=""
case "${TARGET:-}" in
  arm64* | aarch64*)
    # Force enable i8mm for arm64, required by ffmpeg
    # TODO: Check if A10 actually supports this
    features="i8mm"
    ;;
esac

for feature in "${cpu_features[@]}"; do
  case "$CMD" in
    clang*) ;;
    *)
      if [ "$assembler" -eq 0 ] || [ "$preprocessor" -eq 1 ]; then
        # Zig specific changes
        case "$feature" in
          fp16)
            feature="fullfp16"
            ;;
        esac
      fi
      ;;
  esac

  features="${features}\n${feature}"
done

if [ -n "$features" ]; then
  features="$(printf "$features" | awk '!NF || !seen[$0]++' | xargs -r printf '+%s')"
fi

case "${TARGET:-}" in
  x86_64*)
    case "${TARGET:-}" in
      *darwin*)
        # macOS 10.15 (Catalina) only supports Macs made with Ivy Bridge or later
        c_argv+=("-march=ivybridge${features}")
        ;;
      *)
        c_argv+=("-march=x86_64_v2${features}")
        ;;
    esac
    ;;
  arm64* | aarch64*)
    if [ "$preprocessor" -eq 0 ] && { [ $assembler -eq 1 ] || [ $assembler_file -eq 1 ]; }; then
      # This is an workaround for zig not supporting passing explict features when compiling assembler code
      # https://github.com/ziglang/zig/issues/10411
      c_argv+=(-Xassembler "-march=armv8.2-a${features}")
    else
      case "${TARGET:-}" in
        *darwin*)
          if [ "$os_iphone" -eq 0 ]; then
            c_argv+=("-mcpu=apple-m1${features}")
          else
            c_argv+=("-mcpu=apple-a10${features}")
          fi
          ;;
        *)
          # Raspberry Pi 3
          c_argv+=("-mcpu=cortex_a53${features}")
          ;;
      esac
    fi
    ;;
esac

# Like -O2, but with extra optimizations to reduce code size
c_argv+=(-Os)

# Resolve sysroot arguments per target
case "$TARGET" in
  *darwin*)
    # If a SDK is defined resolve its absolute path
    if [ -z "$sysroot" ] && [ -d "${SDKROOT:-}" ]; then
      sysroot="$(CDPATH='' cd -- "$SDKROOT" && pwd -P)"
    fi

    # https://stackoverflow.com/a/49560690
    c_argv+=('-DTARGET_OS_MAC=1')
    if [ "$os_iphone" -eq 1 ]; then
      # FIX-ME: Will need to expand this if we ever support tvOS/visionOS/watchOS
      c_argv+=('-DTARGET_OS_IPHONE=1' '-DTARGET_OS_IOS=1')
    elif [ "$os_iphone" -eq 2 ]; then
      # FIX-ME: Will need to expand this if we ever support tvOS/visionOS/watchOS simulators
      c_argv+=('-DTARGET_OS_IPHONE=1' '-DTARGET_OS_IOS=1' '-DTARGET_OS_SIMULATOR=1')
    else
      c_argv+=('-DTARGET_OS_IPHONE=0')
    fi

    if [ -n "$sysroot" ]; then
      c_argv+=(
        "--sysroot=${sysroot}"
        '-isysroot' "$sysroot"
      )

      if [ $is_cpp -eq 1 ]; then
        c_argv+=('-isystem' "${sysroot}/usr/include/c++/v1")
      fi

      c_argv+=('-isystem' "${sysroot}/usr/include")
    fi
    ;;
  *)
    if [ -n "$sysroot" ]; then
      c_argv+=("--sysroot=${sysroot}" '-isysroot' "$sysroot")
    fi
    ;;
esac

# Add linker args back
for arg in "${l_args[@]}"; do
  c_argv+=("-Wl,$arg")
done

# Zig's behaves very oddly when stdin is used, so we use a temporary file instead
# https://github.com/ziglang/zig/issues/10389
if [ $stdin -eq 1 ]; then
  if [ $assembler -eq 1 ]; then
    _file=$(mktemp __zig_fix_stdin.XXXXXX.S)
  else
    _file=$(mktemp __zig_fix_stdin.XXXXXX.c)
  fi

  trap 'rm -f $_file' EXIT

  cat >"$_file"

  argv+=("$_file")
elif [ $assembler -eq 1 ] && ! [ $assembler_file -eq 1 ]; then
  echo "Assembler mode without stdin or an explicit assembly file is not supported" >&2
  exit 1
fi

# https://stackoverflow.com/q/11027679#answer-59592881
# SYNTAX:
#   catch STDOUT_VARIABLE STDERR_VARIABLE COMMAND [ARG1[ ARG2[ ...[ ARGN]]]]
catch() {
  {
    IFS=$'\n' read -r -d '' "${1}"
    IFS=$'\n' read -r -d '' "${2}"
    (
      IFS=$'\n' read -r -d '' _ERRNO_
      return "$_ERRNO_"
    )
  } < <((printf '\0%s\0%d\0' "$( ( ( ({
    shift 2
    "${@}"
    echo "${?}" 1>&3-
  } | tr -d '\0' 1>&4-) 4>&2- 2>&1- | tr -d '\0' 1>&4-) 3>&1- | exit "$(cat)") 4>&1-)" "${?}" 1>&2) 2>&1)
}

if [ "${_USING_GAS_PREPROCESSOR:-0}" -eq 0 ] && [ "$preprocessor" -eq 0 ] && {
  [ $assembler -eq 1 ] || [ $assembler_file -eq 1 ]
}; then
  _cc_out=
  _cc_err=
  if catch _cc_out _cc_err $CMD "${c_argv[@]}" "${argv[@]}"; then
    printf '%s' "$_cc_out"
    printf '%s' "$_cc_err" >&2
  else
    _gas_out=
    _gas_err=
    export _USING_GAS_PREPROCESSOR=1
    # If zig failed to compile the assembly, try again through gas-preprocessor.pl
    if catch _gas_out _gas_err gas-preprocessor.pl -arch "${TARGET%%-*}" -as-type clang -- "$0" "${args_bak[@]}"; then
      printf '%s' "$_gas_out"
      printf '%s' "$_gas_err" >&2
    else
      printf '%s' "$_cc_out"
      printf '%s' "$_cc_err" >&2
      printf '%s' "$_gas_out"
      printf '%s' "$_gas_err" >&2
      exit 1
    fi
  fi
else
  exec $CMD "${c_argv[@]}" "${argv[@]}"
fi
