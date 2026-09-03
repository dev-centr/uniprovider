module uniprovider.paths;

import std.file : exists, mkdirRecurse;
import std.path : buildPath;
import std.process : environment;

/// Platform registry roots where provider manifests may appear.
string[] registryRoots()
{
    string[] roots;
    version (Windows)
    {
        auto localApp = environment.get("LOCALAPPDATA");
        if (localApp.length)
        {
            roots ~= buildPath(localApp, "uniprovider", "providers");
            roots ~= buildPath(localApp, "opr", "providers");
        }
        auto programData = environment.get("ProgramData");
        if (programData.length)
        {
            roots ~= buildPath(programData, "uniprovider", "providers");
            roots ~= buildPath(programData, "opr", "providers");
        }
    }
    else
    {
        string cfg;
        auto xdg = environment.get("XDG_CONFIG_HOME");
        if (xdg.length)
            cfg = xdg;
        else
        {
            auto home = environment.get("HOME");
            if (home.length)
                cfg = buildPath(home, ".config");
        }
        if (cfg.length)
        {
            roots ~= buildPath(cfg, "uniprovider", "providers");
            roots ~= buildPath(cfg, "opr", "providers");
        }
        roots ~= "/etc/uniprovider/providers";
        roots ~= "/etc/opr/providers";
    }
    return roots;
}

string userWriteRoot()
{
    version (Windows)
    {
        auto localApp = environment.get("LOCALAPPDATA");
        if (localApp.length)
            return buildPath(localApp, "opr", "providers");
    }
    else
    {
        auto xdg = environment.get("XDG_CONFIG_HOME");
        if (xdg.length)
            return buildPath(xdg, "opr", "providers");
        auto home = environment.get("HOME");
        if (home.length)
            return buildPath(home, ".config", "opr", "providers");
    }
    return "opr-providers";
}

void ensureUserWriteRoot()
{
    auto root = userWriteRoot();
    if (!exists(root))
        mkdirRecurse(root);
}
