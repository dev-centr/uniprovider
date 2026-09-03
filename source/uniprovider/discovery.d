module uniprovider.discovery;

import uniprovider.known;
import uniprovider.models;
import uniprovider.registry;

import std.algorithm : filter, map, sort, uniq;
import std.array : array, appender;

/// Merge OPR manifests with well-known probes.
/// Manifests win on id collision (runners that registered themselves).
ProviderRecord[] discoverAll(bool includeUnreachableProbes = false)
{
    auto manifests = loadManifests();
    auto probed = probeKnown();
    if (!includeUnreachableProbes)
        probed = reachableOnly(probed);

    bool[string] seen;
    auto outp = appender!(ProviderRecord[]);
    foreach (m; manifests)
    {
        if (!m.id.length)
            continue;
        seen[m.id] = true;
        outp ~= m;
    }
    foreach (p; probed)
    {
        if (p.id in seen)
            continue;
        seen[p.id] = true;
        outp ~= p;
    }
    return outp.data;
}

ProviderRecord[] discoverOnline()
{
    return discoverAll(true).filter!(p => p.klass == ProviderClass.online
            || p.klass == ProviderClass.hybrid).array;
}

ProviderRecord[] discoverOffline()
{
    return discoverAll(true).filter!(p => p.klass == ProviderClass.offline
            || p.klass == ProviderClass.hybrid).array;
}
