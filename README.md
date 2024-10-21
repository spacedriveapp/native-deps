# Spacedrive native dependencies

## Build instructions

To build the native dependencies a `docker` or `podman` installation is required.
It is recomended to enable [`BuildKit`](https://docs.docker.com/build/buildkit/#getting-started) in docker.

Just run the following inside this directory:

```sh
$> docker build --build-arg TARGET=<TARGET> -o . .
```

or

```sh
$> podman build --jobs 4 --format docker --build-arg TARGET=<TARGET> -o . .
```

Where `<TARGET>` is one of:

- x86_64-darwin-apple
- aarch64-darwin-apple
- x86_64-windows-gnu
- aarch64-windows-gnu
- x86_64-linux-gnu
- aarch64-linux-gnu
- x86_64-linux-musl
- aarch64-linux-musl
- x86_64-linux-android
- aarch64-linux-android

> To build for iOS choose one of the `darwin` targets and pass `--build-arg OS_IPHONE=<1|2>` as an argument, `1` means iOS and `2` means iOS Simulator. Only iOS simulator supports `x86_64`.

After some time (it takes aroung 1~2 hours in Github CI) a directory named `out` will show up in the current directory containing our native dependencies.

## TODO (Order of importance)

- Fortify linux-musl shared libs:
    > https://git.2f30.org/fortify-headers/file/README.html
- Add stack check to windows dlls whenever zig adds support to it:
    > https://github.com/ziglang/zig/blob/b3462b7/src/target.zig#L326-L329
- Add stack check/protector to linux arm64 shared libs whenever zig fix the bug preventing it from working:
    > https://github.com/ziglang/zig/issues/17430#issuecomment-1752592338
- Add support for pthread in windows builds:
    > https://github.com/GerHobbelt/pthread-win32
    > https://sourceforge.net/p/mingw-w64/mingw-w64/ci/master/tree/mingw-w64-libraries/winpthreads/
    > https://github.com/msys2/MINGW-packages/blob/f4bd368/mingw-w64-winpthreads-git/PKGBUILD
- Add libplacebo and vulkan support for apple builds through MoltenVK:
    > https://github.com/KhronosGroup/MoltenVK
- Add Metal shader support for ffmpeg in apple builds:
    > https://github.com/darlinghq/darling/issues/326
- Investigate why LTO fails at linking ffmpeg's libav* libs for windows builds
- Investigate why LTO fails when linking any static lib in apple builds:
    > https://github.com/tpoechtrager/osxcross/issues/366

## Acknowledgments

This build system is losely base on:

- https://github.com/BtbN/FFmpeg-Builds

It uses Zig 0.12 as a C/C++ toolchain to build the Windows and Linux targets:

- https://github.com/ziglang/zig/tree/0.11.0

It uses LLVM/Clang 17 with some tweaks from osxcross + Apple's cctools and linker to build the Darwin (macOS, iOS) targets:

- https://github.com/llvm/llvm-project/tree/llvmorg-17.0.6
- https://github.com/tpoechtrager/osxcross
- https://github.com/tpoechtrager/cctools-port

> By building the Darwin target you are agreeing with the [Apple Public Source License (APSL)](https://opensource.apple.com/apsl/) and the [Xcode license terms](https://www.apple.com/legal/sla/docs/xcode.pdf)

Thanks to all the developers involved in making the dependencies used by this project
