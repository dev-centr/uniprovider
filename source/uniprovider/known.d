module uniprovider.known;

import uniprovider.models;

import core.time : msecs;
import std.array : appender;
import std.json : parseJSON;
import std.net.curl : HTTP, get;

/// Well-known local runners UniProvider probes during the transition period
/// before every runner ships OPR manifests on install.
struct KnownEndpoint
{
    string id;
    string displayName;
    string baseUrl;
    string apiFormat = "openai";
    string healthPath = "/v1/models"; /// relative to host root when base includes /v1
    bool keyless = true;
    string[] tags;
}

immutable KnownEndpoint[] defaultKnown = [
    KnownEndpoint("ollama", "Ollama", "http://127.0.0.1:11434/v1", "openai", "/models", true, [
        "offline", "local"
    ]),
    KnownEndpoint("lm-studio", "LM Studio", "http://127.0.0.1:1234/v1", "openai", "/models", true, [
        "offline", "local"
    ]),
    KnownEndpoint("llama-cpp", "llama.cpp server", "http://127.0.0.1:8080/v1", "openai", "/models", true, [
        "offline", "local", "llama.cpp"
    ]),
    KnownEndpoint("vllm", "vLLM", "http://127.0.0.1:8000/v1", "openai", "/models", true, [
        "offline", "local"
    ]),
    KnownEndpoint("localai", "LocalAI", "http://127.0.0.1:8080/v1", "openai", "/models", true, [
        "offline", "local"
    ]),
];

ProviderRecord[] probeKnown(const(KnownEndpoint)[] known = defaultKnown, uint timeoutMs = 400)
{
    auto outp = appender!(ProviderRecord[]);
    foreach (k; known)
    {
        auto rec = ProviderRecord(k.id, k.displayName, ProviderClass.offline, k.baseUrl, k.apiFormat, k
                .keyless, k.tags.dup, null, "probe", false);
        try
        {
            auto url = k.baseUrl.dup;
            if (url.length && url[$ - 1] == '/')
                url = url[0 .. $ - 1];
            // healthPath is relative to /v1 when baseUrl ends with /v1
            auto probeUrl = url ~ k.healthPath;
            auto http = HTTP();
            http.connectTimeout = timeoutMs.msecs;
            http.operationTimeout = timeoutMs.msecs;
            auto body = cast(string) get(probeUrl, http);
            rec.reachable = true;
            rec.models = parseModelsList(body);
        }
        catch (Exception)
        {
            rec.reachable = false;
        }
        outp ~= rec;
    }
    return outp.data;
}

ModelRef[] parseModelsList(string jsonBody)
{
    ModelRef[] models;
    try
    {
        auto j = parseJSON(jsonBody);
        if ("data" in j)
        {
            foreach (item; j["data"].array)
            {
                string id;
                if ("id" in item)
                    id = item["id"].str;
                if (id.length)
                    models ~= ModelRef(id, id);
            }
        }
    }
    catch (Exception)
    {
    }
    return models;
}

ProviderRecord[] reachableOnly(ProviderRecord[] all)
{
    ProviderRecord[] outp;
    foreach (p; all)
        if (p.reachable)
            outp ~= p;
    return outp;
}
