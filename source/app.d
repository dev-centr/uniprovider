module app;

import uniprovider;

import std.stdio : writeln, writefln;
import std.conv : to;

int main(string[] args)
{
    if (args.length < 2)
    {
        usage();
        return 1;
    }
    auto cmd = args[1];
    switch (cmd)
    {
    case "list":
    case "discover":
        auto all = discoverAll(true);
        if (!all.length)
        {
            writeln("No providers found (no OPR manifests and no reachable well-known endpoints).");
            return 0;
        }
        writeln(summarize(all));
        return 0;
    case "serve":
    case "aggregator":
        string host = "127.0.0.1";
        ushort port = 39200;
        for (size_t i = 2; i < args.length; ++i)
        {
            if (args[i] == "--host" && i + 1 < args.length)
                host = args[++i];
            else if (args[i] == "--port" && i + 1 < args.length)
                port = args[++i].to!ushort;
        }
        runAggregator(host, port);
        return 0;
    case "register":
        // uniprovider register --id foo --base-url http://127.0.0.1:9/v1 --name "Foo"
        ProviderRecord p;
        p.klass = ProviderClass.offline;
        p.apiFormat = "openai";
        p.keyless = true;
        for (size_t i = 2; i < args.length; ++i)
        {
            auto a = args[i];
            if (a == "--id" && i + 1 < args.length)
                p.id = args[++i];
            else if ((a == "--name" || a == "--display-name") && i + 1 < args.length)
                p.displayName = args[++i];
            else if ((a == "--base-url" || a == "--base_url") && i + 1 < args.length)
                p.baseUrl = args[++i];
            else if (a == "--class" && i + 1 < args.length)
                p.klass = parseProviderClass(args[++i]);
            else if (a == "--api-format" && i + 1 < args.length)
                p.apiFormat = args[++i];
            else if (a == "--model" && i + 1 < args.length)
                p.models ~= ModelRef(args[++i], args[i]);
            else if (a == "--tag" && i + 1 < args.length)
                p.tags ~= args[++i];
        }
        auto path = registerProvider(p);
        writefln("Wrote OPR manifest: %s", path);
        return 0;
    case "roots":
        foreach (r; registryRoots())
            writeln(r);
        return 0;
    case "help":
    case "--help":
    case "-h":
        usage();
        return 0;
    default:
        writefln("Unknown command: %s", cmd);
        usage();
        return 1;
    }
}

void usage()
{
    writeln("uniprovider — Open Provider Registry (OPR) reference implementation");
    writeln("Usage:");
    writeln("  uniprovider list");
    writeln("  uniprovider serve [--host 127.0.0.1] [--port 39200]");
    writeln("  uniprovider register --id <slug> --base-url <url> [--name ...] [--model ...] [--class offline|online|hybrid]");
    writeln("  uniprovider roots");
    writeln("");
    writeln("Protocol: Open Provider Registry (OPR) — see spec/opr.md");
    writeln("Apps should prefer OPR over inventing another unilayer registration format.");
}
