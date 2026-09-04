# OpenMU + MuMain — Build-Ready Repository

This repository combines:

- `server/` — OpenMU server source
- `client/` — MuMain client source
- `.github/workflows/build.yml` — GitHub Actions CI for the complete source tree

## GitHub Actions

Every push and pull request builds:

1. **OpenMU Server** with .NET 10 on Ubuntu.
2. **MuMain Client x64 Release** on Windows.
3. **MuMain Client x86 Release** on Windows.

The client build also builds the .NET Client Library and uses the repository's
CMake dependency handling. SDL3/SDL3_mixer/imgui are fetched from their
configured Git submodules when required.

## Local server build

Requirements: .NET 10 SDK and PostgreSQL for runtime.

```bash
cd server/src
dotnet restore MUnique.OpenMU.sln
dotnet build MUnique.OpenMU.sln -c Release
```

## Local client build (Windows)

Requirements: Visual Studio 2022 with C++ tools, CMake 3.25+, Git, and .NET 10 SDK.

```powershell
cmake -S client -B build/client-x64 -G "Visual Studio 17 2022" -A x64 -DENABLE_EDITOR=OFF
cmake --build build/client-x64 --config Release --parallel
```

For 32-bit:

```powershell
cmake -S client -B build/client-x86 -G "Visual Studio 17 2022" -A Win32 -DENABLE_EDITOR=OFF
cmake --build build/client-x86 --config Release --parallel
```

## Runtime assets

The source repository intentionally does **not** include the game's proprietary
runtime data/fonts and deployment DLLs. The CI therefore validates the source
build without requiring those runtime assets. To run the client as a complete
game, provide the appropriate `client/src/bin` runtime package separately.

## Repository policy

Build outputs, IDE caches, tests, deployment artifacts, and documentation-only
files are not part of this source-focused repository.
