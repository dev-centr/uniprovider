module uniprovider.registry;

import uniprovider.models;
import uniprovider.paths;

import std.algorithm : endsWith, filter, map;
import std.array : array, appender;
import std.file : dirEntries, exists, readText, write, SpanMode;
import std.json : JSONValue, JSONType, parseJSON;
import std.path : baseName, buildPath, stripExtension;
import std.string : strip, splitLines, startsWith, indexOf;

/// Load OPR provider manifests from registry roots.
/// Accepts JSON (`.json` / `.opr.json`) and a minimal line-oriented `.opr` text form.
ProviderRecord[] loadManifests(string[] roots = registryRoots())
{
    auto outp = appender!(ProviderRecord[]);
    foreach (root; roots)
    {
        if (!exists(root))
            continue;
        foreach (e; dirEntries(root, SpanMode.shallow))
        {
            if (!e.isFile)
                continue;
            auto name = e.name;
            if (name.endsWith(".json") || name.endsWith(".opr.json"))
            {
                try
                    outp ~= parseJsonManifest(readText(name), "manifest");
                catch (Exception)
                {
                }
            }
            else if (name.endsWith(".opr"))
            {
                try
                    outp ~= parseOprText(readText(name), "manifest");
                catch (Exception)
                {
                }
            }
        }
    }
    return outp.data;
}

ProviderRecord parseJsonManifest(string text, string source)
{
    auto j = parseJSON(text);
    ProviderRecord p;
    p.source = source;
    if ("id" in j)
        p.id = j["id"].str;
    if ("display_name" in j)
        p.displayName = j["display_name"].str;
    else if ("name" in j)
        p.displayName = j["name"].str;
    if (!p.displayName.length)
        p.displayName = p.id;
    if ("class" in j)
        p.klass = parseProviderClass(j["class"].str);
    if ("base_url" in j)
        p.baseUrl = j["base_url"].str;
    else if ("baseUrl" in j)
        p.baseUrl = j["baseUrl"].str;
    if ("api_format" in j)
        p.apiFormat = j["api_format"].str;
    else if ("apiFormat" in j)
        p.apiFormat = j["apiFormat"].str;
    if ("keyless" in j)
        p.keyless = j["keyless"].type == JSONType.true_;
    if ("tags" in j)
        foreach (t; j["tags"].array)
            p.tags ~= t.str;
    if ("models" in j)
    {
        foreach (m; j["models"].array)
        {
            if (m.type == JSONType.string)
                p.models ~= ModelRef(m.str, m.str);
            else if ("id" in m)
                p.models ~= ModelRef(m["id"].str, ("name" in m) ? m["name"].str : m["id"].str);
        }
    }
    p.reachable = true; // manifest asserts presence; probe may refine later
    return p;
}

/// Minimal text form for runners that dislike JSON:
///   id: acme-runner
///   display_name: Acme Runner
///   class: offline
///   base_url: http://127.0.0.1:9999/v1
///   api_format: openai
///   keyless: true
///   tag: local
///   model: acme-7b
ProviderRecord parseOprText(string text, string source)
{
    ProviderRecord p;
    p.source = source;
    p.apiFormat = "openai";
    p.keyless = true;
    p.klass = ProviderClass.offline;
    foreach (line; text.splitLines)
    {
        auto s = line.strip;
        if (!s.length || s.startsWith("#") || s.startsWith("//"))
            continue;
        auto colon = s.indexOf(':');
        if (colon < 0)
            continue;
        auto key = s[0 .. colon].strip;
        auto val = s[colon + 1 .. $].strip;
        switch (key)
        {
        case "id":
            p.id = val;
            break;
        case "display_name":
        case "name":
            p.displayName = val;
            break;
        case "class":
            p.klass = parseProviderClass(val);
            break;
        case "base_url":
            p.baseUrl = val;
            break;
        case "api_format":
            p.apiFormat = val;
            break;
        case "keyless":
            p.keyless = val == "true" || val == "1" || val == "yes";
            break;
        case "tag":
            p.tags ~= val;
            break;
        case "model":
            p.models ~= ModelRef(val, val);
            break;
        default:
            break;
        }
    }
    if (!p.displayName.length)
        p.displayName = p.id;
    p.reachable = true;
    return p;
}

/// Write a JSON OPR manifest into the user registry root (installers / first-run).
string registerProvider(ProviderRecord p)
{
    import std.json : JSONValue;

    ensureUserWriteRoot();
    if (!p.id.length)
        throw new Exception("provider id required");
    JSONValue j;
    j["opr_version"] = 1;
    j["id"] = p.id;
    j["display_name"] = p.displayName.length ? p.displayName : p.id;
    j["class"] = providerClassToString(p.klass);
    j["base_url"] = p.baseUrl;
    j["api_format"] = p.apiFormat;
    j["keyless"] = p.keyless;
    JSONValue[] tags;
    foreach (t; p.tags)
        tags ~= JSONValue(t);
    j["tags"] = tags;
    JSONValue[] models;
    foreach (m; p.models)
    {
        JSONValue mo;
        mo["id"] = m.id;
        if (m.displayName.length)
            mo["name"] = m.displayName;
        models ~= mo;
    }
    j["models"] = models;
    auto path = buildPath(userWriteRoot(), p.id ~ ".opr.json");
    write(path, j.toPrettyString());
    return path;
}
