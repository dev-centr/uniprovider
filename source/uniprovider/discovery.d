module uniprovider.discovery;

import uniprovider.directory;
import uniprovider.known;
import uniprovider.models;
import uniprovider.registry;

import std.algorithm : filter, map, sort, uniq;
import std.array : array, appender;

/// Merge OPR manifests, optional online directory, and well-known probes.
/// Precedence on id collision: local manifests > directory > probes.
ProviderRecord[] discoverAll(bool includeUnreachableProbes = false)
{
    auto manifests = loadManifests();
    auto remote = fetchDirectoryProviders();
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
    foreach (r; remote)
    {
        if (!r.id.length || r.id in seen)
            continue;
        seen[r.id] = true;
        outp ~= r;
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
