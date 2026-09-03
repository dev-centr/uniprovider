module uniprovider.serve;

import uniprovider.discovery;
import uniprovider.models;

import std.array : split;
import std.conv : to;
import std.json : JSONValue;
import std.socket;
import std.stdio : writeln;
import std.string : indexOf, strip;

/// Minimal localhost OpenAI-compat facade over discovered providers.
/// Apps (SoloMD, Hornet/Mixr, IDEs) speak one base URL; UniProvider lists
/// models from every registered/probed runner. Completion proxying is
/// intentionally thin in v0 — prefer apps calling the provider base_url
/// directly once discovery has named it.
void runAggregator(string host = "127.0.0.1", ushort port = 39200)
{
    auto addr = parseAddress(host, port);
    auto listener = new Socket(AddressFamily.INET, SocketType.STREAM, ProtocolType.TCP);
    listener.setOption(SocketOptionLevel.SOCKET, SocketOption.REUSEADDR, 1);
    listener.bind(addr);
    listener.listen(16);
    scope (exit)
        listener.close();

    writeln("UniProvider OPR aggregator http://", host, ":", port);
    writeln("  GET /health");
    writeln("  GET /v1/models");
    writeln("  GET /v1/providers");
    writeln("  GET /opr/v1/providers  (protocol alias)");

    for (;;)
    {
        Socket client = listener.accept();
        scope (exit)
            client.close();
        ubyte[65536] buf;
        auto n = client.receive(buf);
        if (n <= 0)
            continue;
        auto req = cast(string) buf[0 .. n];
        auto resp = handleRequest(req);
        client.send(cast(ubyte[]) resp);
    }
}

string handleRequest(string req)
{
    auto lineEnd = req.indexOf("\r\n");
    if (lineEnd < 0)
        return httpResponse(400, "text/plain", "bad request");
    auto requestLine = req[0 .. lineEnd].strip;
    auto parts = requestLine.split(" ");
    if (parts.length < 2)
        return httpResponse(400, "text/plain", "bad request");
    auto method = parts[0];
    auto path = parts[1];
    auto q = path.indexOf('?');
    if (q >= 0)
        path = path[0 .. q];

    if (method == "GET" && (path == "/health" || path == "/opr/v1/health"))
    {
        JSONValue j;
        j["ok"] = true;
        j["protocol"] = "opr";
        j["opr_version"] = 1;
        j["implementation"] = "uniprovider";
        return httpResponse(200, "application/json", j.toString());
    }

    if (method == "GET" && (path == "/v1/providers" || path == "/opr/v1/providers"))
    {
        auto providers = discoverAll(true);
        JSONValue root;
        root["opr_version"] = 1;
        JSONValue[] arr;
        foreach (p; providers)
        {
            JSONValue o;
            o["id"] = p.id;
            o["display_name"] = p.displayName;
            o["class"] = providerClassToString(p.klass);
            o["base_url"] = p.baseUrl;
            o["api_format"] = p.apiFormat;
            o["keyless"] = p.keyless;
            o["source"] = p.source;
            o["reachable"] = p.reachable;
            JSONValue[] tags;
            foreach (t; p.tags)
                tags ~= JSONValue(t);
            o["tags"] = tags;
            JSONValue[] models;
            foreach (m; p.models)
            {
                JSONValue mo;
                mo["id"] = m.id;
                mo["name"] = m.displayName.length ? m.displayName : m.id;
                models ~= mo;
            }
            o["models"] = models;
            arr ~= o;
        }
        root["providers"] = arr;
        return httpResponse(200, "application/json", root.toString());
    }

    if (method == "GET" && path == "/v1/models")
    {
        auto providers = discoverAll(false);
        return httpResponse(200, "application/json", toJsonCatalog(providers));
    }

    if (method == "OPTIONS")
        return httpResponse(204, "text/plain", "");

    return httpResponse(404, "application/json", `{"error":"not found"}`);
}

string httpResponse(int code, string contentType, string body)
{
    auto reason = code == 200 ? "OK" : code == 204 ? "No Content" : code == 400 ? "Bad Request" : "Not Found";
    import std.array : appender;

    auto a = appender!string();
    a ~= "HTTP/1.1 ";
    a ~= code.to!string;
    a ~= " ";
    a ~= reason;
    a ~= "\r\n";
    a ~= "Content-Type: ";
    a ~= contentType;
    a ~= "\r\n";
    a ~= "Access-Control-Allow-Origin: *\r\n";
    a ~= "Access-Control-Allow-Methods: GET, OPTIONS\r\n";
    a ~= "Connection: close\r\n";
    a ~= "Content-Length: ";
    a ~= body.length.to!string;
    a ~= "\r\n\r\n";
    a ~= body;
    return a.data;
}
