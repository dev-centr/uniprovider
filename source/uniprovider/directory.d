module uniprovider.directory;

import uniprovider.models;

import core.time : seconds;
import std.array : appender;
import std.json : JSONType, JSONValue, parseJSON;
import std.net.curl : HTTP, get;
import std.process : environment;
import std.string : strip;

/// Optional online OPR Directory base (no trailing slash), e.g. https://providers.devcentr.org
string directoryBaseUrl()
{
    auto v = environment.get("OPR_DIRECTORY_URL", "").strip;
    if (!v.length)
        return "";
    while (v.length && v[$ - 1] == '/')
        v = v[0 .. $ - 1];
    return v;
}

/// Poll GET {OPR_DIRECTORY_URL}/opr/v1/providers when the env var is set.
/// Failures are soft — local discovery still works.
ProviderRecord[] fetchDirectoryProviders(uint timeoutSec = 5)
{
    auto base = directoryBaseUrl();
    if (!base.length)
        return null;

    auto outp = appender!(ProviderRecord[]);
    try
    {
        auto http = HTTP();
        http.connectTimeout = timeoutSec.seconds;
        http.operationTimeout = timeoutSec.seconds;
        auto body = cast(string) get(base ~ "/opr/v1/providers", http);
        auto j = parseJSON(body);
        if ("providers" !in j)
            return outp.data;
        foreach (item; j["providers"].array)
            outp ~= recordFromDirectoryJson(item);
    }
    catch (Exception)
    {
        // Soft-fail: offline machine or directory down.
    }
    return outp.data;
}

ProviderRecord recordFromDirectoryJson(JSONValue item)
{
    ProviderRecord rec;
    rec.source = "directory";
    rec.reachable = true;
    if ("id" in item)
        rec.id = item["id"].str;
    if ("display_name" in item)
        rec.displayName = item["display_name"].str;
    else
        rec.displayName = rec.id;
    if ("class" in item)
        rec.klass = parseProviderClass(item["class"].str);
    if ("base_url" in item)
        rec.baseUrl = item["base_url"].str;
    if ("api_format" in item)
        rec.apiFormat = item["api_format"].str;
    if ("keyless" in item)
        rec.keyless = item["keyless"].type == JSONType.true_
            || (item["keyless"].type == JSONType.integer && item["keyless"].integer != 0);
    if ("tags" in item)
        foreach (t; item["tags"].array)
            rec.tags ~= t.str;
    if ("models" in item)
    {
        foreach (m; item["models"].array)
        {
            if (m.type == JSONType.string)
                rec.models ~= ModelRef(m.str, m.str);
            else if ("id" in m)
            {
                auto mid = m["id"].str;
                auto name = ("name" in m) ? m["name"].str : mid;
                rec.models ~= ModelRef(mid, name);
            }
        }
    }
    return rec;
}
