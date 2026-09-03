# Open Provider Registry (OPR)

**Status:** Draft v0.1 (2026-09-02)  
**License:** MIT (this document and example manifests)  
**Reference implementation:** [dev-centr/uniprovider](https://github.com/dev-centr/uniprovider)

## Why this exists

Desktop apps, agent harnesses, and markdown editors keep inventing their own “local model” integration. One app auto-detects Ollama. Another hard-codes LM Studio’s port. A third ships a private “unilayer” registration scheme. Offline model runners then face an endless checklist of proprietary discovery formats.

**OPR is the opposite bet:** one open registration and exposure protocol. Runners implement OPR once. Any aggregator, IDE, or editor that speaks OPR can find them. Competing aggregator *products* remain welcome; competing registration *formats* are the problem.

UniProvider is Dev-Centr’s reference consumer and transitional well-known probe set. The protocol name is **OPR**, not UniProvider. Other orgs should implement OPR without depending on our daemon.

## Goals

1. **Register once** — on install / first-run, a runner writes a manifest into a well-known directory (and/or serves the live HTTP surface).
2. **Expose online and offline** — cloud BYOK endpoints and local weight runners share the same record shape; `class` distinguishes them.
3. **Stay discoverable without us** — directory + HTTP are enough; no central cloud registry required.
4. **Stay boring** — JSON manifests + OpenAI-compatible HTTP where possible. No mandatory RPC, no mandatory WASM, no mandatory D.

## Non-goals (v0)

- Choosing which model is “best” for a job (that is routing — e.g. Hornet **Mixr**).
- Replacing vendor APIs or API-key vaults.
- Forcing every runner to embed our library (file drop is enough).
- **A public online registration directory** that niche providers join and apps poll worldwide. That is a separate product: [dev-centr/opr-directory](https://github.com/dev-centr/opr-directory) (SolidStart · Netlify/Vercel · planned `providers.devcentr.org`). UniProvider stays local-first.

## Prior art (why OPR still exists)

| Thing | What it solves | Gap vs OPR |
| --- | --- | --- |
| OpenAI-compatible HTTP | Common call/list wire format | No registration; each app still hard-codes who to probe |
| OpenRouter | Hosted curated multi-model marketplace | Not open self-serve runner registration; not local disk discovery |
| LiteLLM proxy | Operator-configured gateway (YAML/UI/DB) | Config owned by the operator, not a shared on-disk protocol runners write on install |
| Olla | Strong local/self-hosted proxy + profile system | Profiles are aggregator-maintained; runners do not drop a neutral manifest for *any* consumer |
| UPP ([ProviderProtocol/ai](https://github.com/ProviderProtocol/ai)) | Client/SDK call abstraction across modalities | Not machine-local discovery registration |
| App-private registries (SoloMD, ArgentOS, DeepAgents RFCs, …) | Per-product catalogs + a few auto-detect ports | Exactly the unilayer fragmentation OPR tries to stop |

**Verdict:** the idea is **not invalidated**. Proxies and marketplaces exist; a **neutral, open registration/exposure format** that runners maintain once (and that both local aggregators and future online directories can read) is still thinly served. Prefer implementing OPR and *feeding* Olla/LiteLLM/SoloMD rather than replacing them.

## Directory discovery

Consumers scan these roots (create-if-missing only for *writers*):

| Platform | User (writable) | System (optional) |
| --- | --- | --- |
| Windows | `%LOCALAPPDATA%\opr\providers\` | `%ProgramData%\opr\providers\` |
| macOS / Linux | `${XDG_CONFIG_HOME:-~/.config}/opr/providers/` | `/etc/opr/providers/` |

**Filename:** `<id>.opr.json` (preferred) or `<id>.opr` (line-oriented text).

Legacy alias roots under `uniprovider/providers/` may also be scanned by the reference implementation; new writers should use `opr/providers/` only.

## Manifest schema (`opr_version: 1`)

```json
{
  "opr_version": 1,
  "id": "lm-studio",
  "display_name": "LM Studio",
  "class": "offline",
  "base_url": "http://127.0.0.1:1234/v1",
  "api_format": "openai",
  "keyless": true,
  "tags": ["local", "gguf"],
  "models": [
    { "id": "qwen2.5-7b-instruct", "name": "Qwen2.5 7B Instruct" }
  ]
}
```

| Field | Required | Notes |
| --- | --- | --- |
| `opr_version` | yes | Integer; this document is `1`. |
| `id` | yes | Stable slug; `[a-z0-9][a-z0-9.-]*`. |
| `display_name` | recommended | Human label. |
| `class` | yes | `offline` \| `online` \| `hybrid`. |
| `base_url` | yes | Prefer OpenAI-compat root ending in `/v1`. |
| `api_format` | yes | `openai` \| `ollama` \| `anthropic` (extensible). |
| `keyless` | no | Default `true` for offline runners. |
| `tags` | no | Free-form strings. |
| `models` | no | May be empty if `GET {base_url}/models` works. |

### Line-oriented `.opr` (optional)

```
id: acme-runner
display_name: Acme Runner
class: offline
base_url: http://127.0.0.1:9999/v1
api_format: openai
keyless: true
tag: local
model: acme-7b
```

## Live HTTP exposure (optional but recommended)

If a runner or aggregator process is listening, it **may** expose:

| Method | Path | Body |
| --- | --- | --- |
| `GET` | `/opr/v1/health` | `{ "ok": true, "opr_version": 1, "protocol": "opr" }` |
| `GET` | `/opr/v1/providers` | `{ "opr_version": 1, "providers": [ /* same fields as manifests */ ] }` |

OpenAI-compat `GET /v1/models` remains useful for single-endpoint runners. Aggregators that merge many runners should prefer `/opr/v1/providers` so `base_url` per provider is preserved.

Default reference aggregator bind: `http://127.0.0.1:39200` (UniProvider). **Port is not part of the protocol** — consumers should read manifests and/or user settings, not hard-code 39200.

## Consumer rules

1. Prefer **manifests** over hard-coded brand ports.
2. When both a manifest and a probe exist for the same `id`, **manifest wins**.
3. Do not invent a second on-disk registration format for the same job. Extend OPR (`opr_version`) instead.
4. Routing / cost policy stays outside OPR (Mixr, app heuristics, user picks).

## Runner / installer obligations

On install or first successful local server start:

1. Write `%…%/opr/providers/<id>.opr.json` with a current `base_url`.
2. Update or remove the file on uninstall / port change.
3. Optionally serve `/opr/v1/*` from the runner process itself.

Using the UniProvider CLI is optional:

```text
uniprovider register --id acme-runner --base-url http://127.0.0.1:9999/v1 --name "Acme Runner"
```

## Relationship to app-specific providers

Editors such as SoloMD may keep first-party BYOK cloud entries and an `openai-compat` slot. OPR does not replace those UX surfaces. It removes the need for each app to special-case every offline runner’s auto-detect story. Pointing an app at an OPR-aware aggregator — or reading OPR manifests directly — is enough.

## Extensibility

- New `api_format` values are allowed; consumers ignore unknown formats safely.
- Additional JSON fields are allowed; unknown fields must be ignored (forward compatible).
- Breaking changes require a new `opr_version`.

## Conformance

A consumer is OPR-conformant if it discovers providers from the directory roots above and understands `opr_version: 1` manifests.

A runner is OPR-conformant if it writes a valid manifest (or serves `/opr/v1/providers` with the same shape) without requiring a proprietary sidecar format.

## Reference materials

- Spec (this file): `spec/opr.md`
- Example manifests: `examples/`
- D library + CLI: this repository
- Bridge note for Tauri / JS: `bridge/README.adoc`
