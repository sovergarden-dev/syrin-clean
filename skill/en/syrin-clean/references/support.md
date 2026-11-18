# Support and qualification

> updated 2026-11-18 · v4.1.0-preview.2

This support matrix accompanies the `4.1.0-preview.2` pre-release. Android USB diagnostics have completed one explicitly authorized read-only run on Android 14 from a Windows host with Python 3.12 and official SDK Platform Tools 37.0.1. This covers the observed collectors, not all phones/OEMs or Android recovery. Android mutation and iOS support are absent. See [device controls](https://github.com/sovergarden-dev/syrin-clean/blob/4.1.0-preview.2/docs/feat/devices.md) and [live validation](https://github.com/sovergarden-dev/syrin-clean/blob/4.1.0-preview.2/docs/research/android-live-validation.md) for exact boundaries.

The preview build is not a stable release or a claim of universal compatibility. The owner explicitly deferred VM qualification because no disposable VM is available and approved a public pre-release with Pages and offline HTML. Do not replace VM qualification with system changes on a real workstation.

| Area | Implemented behavior | Verification boundary |
|---|---|---|
| File plans | Explicit IDs or deterministic `G`-group IDs, plan digest, compact approval receipts, current-user root, immutable session and append-only events | Owned fixtures, a native `CollectPlanFiles` 2,048-file scale regression and an explicitly approved local file workflow on Windows 10/11 x64 |
| File transfer | Same-volume regular files; directories expand to an exact file list; empty directory skeletons remain | Native handle-based no-overwrite rename with `RoundtripKind` UTC verification; fixture recovery, conflicts and journal failure |
| Purge | Separate irreversible operation, selected stored files only; identity checked on the deletion handle | Fixture deletion/replacement-race regression and an approved local cache workflow; raw machine evidence stays private |
| Paths | Local NTFS/ReFS identity APIs and `SHGetKnownFolderPath` resolution; network/device/stream paths, protected data, reparse and recall paths blocked | NTFS fixtures and junctions exercised here; ReFS and other device configurations not qualified |
| Cloud | Registered sync roots, OneDrive environment/accounts, Dropbox path configuration and conventional roots | Synthetic path-boundary tests; actual provider/version behavior and custom locations remain unverified |
| Restore points | New sequence/time verification and frequency-key rollback | Mocked system-call tests only; real System Restore requires a disposable VM |
| Elevation | Quoted native arguments, UAC cancellation (`1223`) distinguished from sandbox `elevation-unsupported` (`5`/`50`/`740`, returning `manualCommand`) | Native child argument round-trip, sandbox Win32 50 fixture and a same-account read-only UAC run; real cancellation and alternate-account elevation remain unverified |
| Installer | Checksums, preparation outside discovery roots, serialized update, retained backups, rollback across default and detected/explicit agent targets | `.claude`, `.agents`, `.codex` and `.gemini\antigravity` targets plus a real failed second commit tested with an isolated profile |
| Audit/report | Versioned collectors (`radar`, `hotspots`, `devArtifacts`, `largeFiles`, `apps`), explicit missing/partial states, volume identity, typed categories, guarded baselines | Fixture/model and JSON Schema contract tests; a full machine audit across Windows versions and hardware remains separate |
| Android USB | Exact `adb.exe` device/current-user selection; bounded read-only system, memory, storage, battery, CPU and optional package/appSizes/thermal/two-point frame collectors | One authorized Android 14 run completed six base collectors and generated private/aggregate HTML; optional `thermal`, `diskstats` and two-point frame deltas covered by unit fixtures. Real frame diagnostics, disconnect recovery, other OEMs and device mutations remain unverified |
| HTML | English-default bilingual landing with Open Graph, Twitter Card and Schema.org JSON-LD; reports with in-place language changes, history search/filtering, restore/purge request preparation, persistent selections, embedded fonts and bounded animation | Actual EN/VI keyboard and 320 px interaction checks; synthetic renderer lifecycle, SEO metadata checks, download hashes and model tests. Real zoom, system reduced-motion/background transitions, native file opening and full screen-reader qualification remain separate |
| Windows/architecture | Target Windows 10/11 with Windows PowerShell 5.1 | Current-host tests do not qualify all Windows editions, x64/ARM64, Admin/non-Admin or filesystems |
| Agent integration | Default `.claude/skills` and `.agents/skills`, plus optional detected/explicit `.codex/skills`, `.cursor/skills` and `.gemini/antigravity/skills`; standalone runtime extraction | File installation verified; end-to-end behavior of every named agent/version remains unverified |

Automatic mutation is limited to the file lifecycle implemented by the bundled runtime. Power-plan changes, startup/service/task changes, driver updates, uninstall, DISM, filesystem repair and hardware procedures remain advice until a tested adapter/procedure is available. This is an explicit safety boundary, not a promise that every diagnostic suggestion has an automatic action.

Quarantine is not a backup and frees no space. Same-volume storage shares the source volume's failure risk. Purge cannot be undone. Recovery also depends on intact files, journals, ownership and access; out-of-band changes, OS reinstall or lost keys may require manual recovery. Do not edit or move the managed storage while an operation is active.

The runtime is not an OS sandbox. A full-shell agent or local administrator can bypass package controls. Approval hashes bind exact plan bytes; they do not authenticate the human. Raw audit reports can contain private paths and metadata. Aggregate exports reduce that information but do not guarantee anonymity.

## Qualification before stable release

Use disposable Windows 10/11 VM snapshots, including ARM64 where available. Verify real Restore Point creation, registry restoration on failure, access denial, file locks, update/reboot states, real cloud placeholders, long/redirected paths and every advertised agent integration. Record the exact source revision, OS build, architecture, PowerShell version and result. Keep unsupported or untested cells explicit.
