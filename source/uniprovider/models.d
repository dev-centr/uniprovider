module uniprovider.models;

import std.algorithm : canFind, map;
import std.array : array, join;
import std.conv : to;
import std.json : JSONValue;
import std.string : strip;

/// Online (API key / vendor cloud) vs offline (weights on owned hardware).
enum ProviderClass
{
    online,
    offline,
    hybrid
}

struct ModelRef
{
    string id;
    string displayName;
}

struct ProviderRecord
{
    string id; /// Stable slug, e.g. `ollama`, `lm-studio`, `acme-runner`.
    string displayName;
    ProviderClass klass = ProviderClass.offline;
    string baseUrl; /// OpenAI-compat root, often ending in `/v1`.
    string apiFormat = "openai"; /// `openai` | `ollama` | `anthropic`
    bool keyless = true;
    string[] tags;
    ModelRef[] models;
    string source; /// `probe`, `manifest`, `register`
    bool reachable; /// Last probe result when known.
}

string toJsonCatalog(const(ProviderRecord)[] providers)
{
    JSONValue root;
    JSONValue[] data;
    foreach (p; providers)
    {
        JSONValue[] modelObjs;
        foreach (m; p.models)
        {
            JSONValue mo;
            mo["id"] = m.id.length ? m.id : (p.id ~ "/" ~ "default");
            mo["object"] = "model";
            mo["owned_by"] = p.id;
            modelObjs ~= mo;
        }
        if (modelObjs.length == 0)
        {
            JSONValue mo;
            mo["id"] = p.id;
            mo["object"] = "model";
            mo["owned_by"] = p.id;
            modelObjs ~= mo;
        }
        foreach (mo; modelObjs)
            data ~= mo;
    }
    root["object"] = "list";
    root["data"] = data;
    return root.toString();
}

string providerClassToString(ProviderClass c)
{
    final switch (c)
    {
    case ProviderClass.online:
        return "online";
    case ProviderClass.offline:
        return "offline";
    case ProviderClass.hybrid:
        return "hybrid";
    }
}

ProviderClass parseProviderClass(string s)
{
    auto t = s.strip;
    if (t == "online")
        return ProviderClass.online;
    if (t == "hybrid")
        return ProviderClass.hybrid;
    return ProviderClass.offline;
}

string summarize(const(ProviderRecord)[] providers)
{
    return providers.map!(p => p.id ~ " (" ~ p.baseUrl ~ ", " ~ providerClassToString(
            p.klass) ~ ", src=" ~ p.source ~ ", up=" ~ p.reachable.to!string ~ ")").join("\n");
}

bool hasId(const(ProviderRecord)[] providers, string id)
{
    return providers.canFind!(p => p.id == id);
}
