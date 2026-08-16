# GWYF Unlimited Players — agent handoff

## Goal

BepInEx + Harmony mod for **Gamble With Your Friends** so the host can run lobbies with **more than 6** players. Plan: **host installs mod**, **`MaxPlayers`** default **12**, clamp **2–16**. Do **not** edit Cursor-managed plan files in the IDE (they live outside this repo).

## Repo layout

| Path | Purpose |
|------|---------|
| [`src/GwyfUnlimitedPlayers/`](src/GwyfUnlimitedPlayers/) | Plugin: `Plugin.cs`, `Patches/*.cs` |
| [`GwyfUnlimitedPlayers.sln`](GwyfUnlimitedPlayers.sln) | Solution |
| [`build.ps1`](build.ps1) | Build script; optional env **`GWYF_MANAGED`** = game `...\Data\Managed` |
| [`README.md`](README.md) | User-facing build/install/config |
| [`docs/TARGETS.md`](docs/TARGETS.md) | How targets were inferred (strings + assemblies); future patch ideas |
| [`docs/VALIDATION.md`](docs/VALIDATION.md) | Manual multiplayer test matrix |
| [`thunderstore/manifest.json`](thunderstore/manifest.json) | Stub Thunderstore metadata (deps empty) |
| *(optional local folder)* | Reference mod docs (PEAK / Photon) — conceptual only; not shipped in this repo |

## Implemented behavior

- **Plugin GUID / name:** `agreenbeen.gwyf.unlimited_players` / **GWYF Unlimited Players** v `1.0.0` ([`Plugin.cs`](src/GwyfUnlimitedPlayers/Plugin.cs)).
- **Config:** `MaxPlayers` (12 default, clamped 2–16), `VerboseLogging`. BepInEx config file name follows GUID: `agreenbeen.gwyf.unlimited_players.cfg`.
- **Harmony patches:**
  - [`NetworkManagerMaxConnectionsPatch.cs`](src/GwyfUnlimitedPlayers/Patches/NetworkManagerMaxConnectionsPatch.cs): `NetworkManager.Awake` postfix + `StartHost` / `StartServer` prefix → set `maxConnections`.
  - [`SteamCreateLobbyPatch.cs`](src/GwyfUnlimitedPlayers/Patches/SteamCreateLobbyPatch.cs): `SteamMatchmaking.CreateLobby(ELobbyType, int)` prefix → `cMaxMembers`.
  - [`SteamSetLobbyMemberLimitPatch.cs`](src/GwyfUnlimitedPlayers/Patches/SteamSetLobbyMemberLimitPatch.cs): `SteamMatchmaking.SetLobbyMemberLimit(CSteamID, int)` prefix → `cMaxMembers`.

## Game facts (for patching / build refs)

- Install layout: Steam `steamapps\common\Gamble With Your Friends\` (drive and library folder vary per machine).
- **Mono** Unity build (`MonoBleedingEdge`); managed assemblies under `Gamble With Your Friends_Data\Managed\`.
- **Networking:** Mirror (`Mirror.dll`) + Steamworks.NET (`com.rlabrecque.steamworks.net.dll`) + FizzySteamworks. Full assembly list: `Gamble With Your Friends_Data\ScriptingAssemblies.json` in the game install (on disk; not committed to this repo).
- String recon surfaced: `LobbyManager`, `GoOnlineClient`, `CustomNetworkManager`, `LobbySettings`, `CreateLobby`, `GetLobbyMemberLimit` — see [`docs/TARGETS.md`](docs/TARGETS.md).

## Build status (last known)

- **`.NET 8 SDK`** + `dotnet build .\GwyfUnlimitedPlayers.sln -c Release -p:GameManaged="…\Gamble With Your Friends_Data\Managed"` succeeds when `lib\BepInEx\BepInEx.dll` is present (BepInEx **5.4.23.5** vendored ref; see [`lib/README.md`](lib/README.md) and [`scripts/FetchBepInExLibs.ps1`](scripts/FetchBepInExLibs.ps1)).
- **Game install:** set **`GameManaged`** to `…\Gamble With Your Friends_Data\Managed` for your install (`.\scripts\Find-GwyfManaged.ps1`, Steam → Browse local files, or `Directory.Build.props` from `Directory.Build.props.example`). There is no machine-specific default in the repo.
- **Runtime:** players install **BepInEx 5.4.x** in the game folder; the plugin targets the same major API as the vendored `BepInEx.dll` (not BepInEx 6).

## Done vs not done

| Done | Not done / verify locally |
|------|---------------------------|
| Plugin skeleton, config, Harmony wiring; Steam + Mirror cap patches | Full **multi-machine** validation per [`docs/VALIDATION.md`](docs/VALIDATION.md) (8 / 12 / 16 players, leave-rejoin) — only single-host smoke-tested so far |
| **`dotnet build`** (Release) with .NET 8 + vendored **`lib/BepInEx/BepInEx.dll`** (5.4.23.5) | If `lib/BepInEx/BepInEx.dll` is missing, run [`scripts/FetchBepInExLibs.ps1`](scripts/FetchBepInExLibs.ps1) and commit the DLL if you want CI/clones to build without the script |
| README, TARGETS, VALIDATION, LICENSE, thunderstore stub | Thunderstore **dependencies** (BepInEx pack name for this game community) if publishing |
| | Optional **game-specific** patches if caps still enforced in `GoOnlineClient` / `LobbyManager` / UI (dnSpy on `Assembly-CSharp.dll`) |

## 2026-08-16: fixed silent Harmony patch-discovery bug (not a game-update break)

`NetworkManagerMaxConnectionsPatch.cs` put `[HarmonyPatch(...)]` only on the three individual
patch methods (`Awake`/`StartHost`/`StartServer`), with no class-level `[HarmonyPatch]`. Turns out
`Harmony.PatchAll()`'s auto-discovery only walks types that carry a **class-level** `[HarmonyPatch]`
attribute — method-level-only attributes make `PatchAll()` skip the whole class silently (no
exception, no log line; `AccessTools.DeclaredMethod` still resolves the targets fine if you check
manually). Confirmed live via `Harmony.GetPatchedMethods()`: only the two Steam patches (which do
use a class-level attribute, matching `SteamCreateLobbyPatch`/`SteamSetLobbyMemberLimitPatch`) were
ever actually applied — **the Mirror `maxConnections` cap has never been raised, since the original
commit**, independent of any game update. Verified against the current live game build (Unity
6000.3.6, v1.0.32, fresh Steam install) that `Mirror.NetworkManager.Awake/StartHost/StartServer`
and the Steamworks.NET signatures are all otherwise unchanged and match the existing patch targets
exactly — so no game-side incompatibility was found.

Fix: split into three separate `[HarmonyPatch(typeof(NetworkManager), "X")]`-annotated classes
(one per target method), mirroring the already-working Steam patch shape. Rebuilt + redeployed to a
live install; `Harmony.GetPatchedMethods()` now lists all 5 patches (confirmed via a temporary
diagnostic log, since removed). The Steam lobby cap patch (`SteamMatchmaking.CreateLobby`) was
confirmed live before and after the fix, correctly rewriting `cMaxMembers` 6 → 12 on lobby creation.
Could not live-verify the Mirror side end-to-end (needs a second real Steam account/joiner — solo
hosting in this environment never actually exercises `NetworkManager.StartHost()`'s connection cap
in a way that's externally observable), so **still do the multi-machine test in
[`docs/VALIDATION.md`](docs/VALIDATION.md) before calling this fully done**.

## Next steps for a resuming agent

1. Discover **`GameManaged`** if needed: **`.\scripts\Find-GwyfManaged.ps1`** (secondary Steam libraries are common). Then run **`build.ps1`**, **`scripts/Pack-Dist.ps1`**, or `dotnet build` with **`-p:GameManaged=`**. Release builds populate **`dist/`** (see [`README.md`](README.md)).
2. Fix any **missing assembly references** in [`GwyfUnlimitedPlayers.csproj`](src/GwyfUnlimitedPlayers/GwyfUnlimitedPlayers.csproj) until the project compiles.
3. Copy built DLL to game **`BepInEx/plugins`**, host-run, grep **`BepInEx/LogOutput.log`** for mod log lines.
4. If joins still cap at 6: open **`Assembly-CSharp.dll`** in dnSpy/ILSpy, search **`CreateLobby`**, **`maxPlayers`**, **`LobbyManager`**, **`maxConnections`**, add Harmony patches on **game** types (not only Steam/Mirror facades).
5. If **`SetLobbyMemberLimit`** or **`CreateLobby`** signatures differ after a game update, adjust patch **`typeof`/argument arrays** or switch to **`HarmonyTargetMethod`** / manual `Patch`.

## Conventions

- Prefer **absolute paths** in tool args when possible; each developer’s game path differs.
- Do not create duplicate todo lists from the plan file; plan todos live in Cursor plan UI.
