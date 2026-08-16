using HarmonyLib;
using Mirror;

namespace GwyfUnlimitedPlayers.Patches;

/// <summary>
/// Mirror rejects connections when <see cref="NetworkManager.maxConnections"/> is too low.
/// Apply configured cap whenever the game's <see cref="NetworkManager"/> initializes or starts hosting/listening.
/// </summary>
internal static class NetworkManagerMaxConnectionsPatchShared
{
    internal static void ApplyMaxConnections(NetworkManager nm, string source)
    {
        int want = GwyfUnlimitedPlayersPlugin.GetEffectiveMaxPlayers();
        int before = nm.maxConnections;
        if (before == want)
        {
            GwyfUnlimitedPlayersPlugin.Verbose($"NetworkManager.{source}: maxConnections already {want}.");
            return;
        }

        nm.maxConnections = want;
        GwyfUnlimitedPlayersPlugin.Log.LogInfo(
            $"NetworkManager.{source}: maxConnections {before} -> {want} ({nm.GetType().FullName})");
    }
}

// Harmony's PatchAll() only auto-discovers classes that carry a class-level [HarmonyPatch]
// attribute; method-level-only attributes (the previous shape of this file) are silently
// skipped by discovery, so these must each be their own [HarmonyPatch]-annotated class
// (matching the pattern used by the Steam patches, which do work).

[HarmonyPatch(typeof(NetworkManager), "Awake")]
internal static class NetworkManagerAwakePatch
{
    [HarmonyPostfix]
    private static void Postfix(NetworkManager __instance)
    {
        if (__instance == null) return;
        NetworkManagerMaxConnectionsPatchShared.ApplyMaxConnections(__instance, nameof(Postfix));
    }
}

[HarmonyPatch(typeof(NetworkManager), nameof(NetworkManager.StartHost))]
internal static class NetworkManagerStartHostPatch
{
    [HarmonyPrefix]
    private static void Prefix(NetworkManager __instance)
    {
        if (__instance == null) return;
        NetworkManagerMaxConnectionsPatchShared.ApplyMaxConnections(__instance, nameof(Prefix));
    }
}

[HarmonyPatch(typeof(NetworkManager), nameof(NetworkManager.StartServer))]
internal static class NetworkManagerStartServerPatch
{
    [HarmonyPrefix]
    private static void Prefix(NetworkManager __instance)
    {
        if (__instance == null) return;
        NetworkManagerMaxConnectionsPatchShared.ApplyMaxConnections(__instance, nameof(Prefix));
    }
}
