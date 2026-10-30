# Support and qualification

> updated 2026-10-30 · v4.0.0-preview.1

The preview build is not a stable release or a claim of universal compatibility. The owner explicitly deferred VM qualification because no disposable VM is available and approved a public pre-release with Pages and offline HTML. Do not replace VM qualification with system changes on a real workstation.

| Area | Implemented behavior | Verification boundary |
|---|---|---|
| File plans | Explicit IDs, plan digest, current-user root, immutable session and append-only events | Owned fixtures, a large-tree regression and an explicitly approved local file workflow on Windows 10 x64 |
| File transfer | Same-volume regular files; directories expand to an exact file list; empty directory skeletons remain | Native handle-based no-overwrite rename; fixture recovery, conflicts and journal failure |
| Purge | Separate irreversible operation, selected stored files only; identity checked on the deletion handle | Fixture deletion/replacement-race regression and an approved local cache workflow; raw machine evidence stays private |
| Paths | Local NTFS/ReFS identity APIs; network/device/stream paths, protected data, reparse and recall paths blocked | NTFS fixtures and junctions exercised here; ReFS and other device configurations not qualified |
| Cloud | Registered sync roots, OneDrive environment/accounts, Dropbox path configuration and conventional roots | Synthetic path-boundary tests; actual provider/version behavior and custom locations remain unverified |
| Restore points | New sequence/time verification and frequency-key rollback | Mocked system-call tests only; real System Restore requires a disposable VM |
| Elevation | Quoted native arguments, UAC cancellation distinguished from other failures | Native child argument round-trip and a same-account read-only UAC run; real cancellation and alternate-account elevation remain unverified |
| Installer | Checksums, preparation outside discovery roots, serialized update, retained backups, rollback | Both agent directories and a real failed second commit tested with an isolated profile |
| Audit/report | Versioned collectors, explicit missing/partial states, volume identity, typed categories, guarded baselines | Fixture/model tests; a full machine audit across Windows versions and hardware remains separate |
| HTML | English-default bilingual landing; reports with in-place language changes, history search/filtering, persistent selections, embedded fonts and bounded animation | Actual EN/VI keyboard and 320 px interaction checks; synthetic renderer lifecycle, download hashes and model tests. Real zoom, system reduced-motion/background transitions, native file opening and full screen-reader qualification remain separate |
| Windows/architecture | Target Windows 10/11 with Windows PowerShell 5.1 | Current-host tests do not qualify all Windows editions, x64/ARM64, Admin/non-Admin or filesystems |
| Agent integration | `.claude/skills` and `.agents/skills`; standalone runtime extraction | File installation verified; end-to-end behavior of every named agent/version remains unverified |

Automatic mutation is limited to the file lifecycle implemented by the bundled runtime. Power-plan changes, startup/service/task changes, driver updates, uninstall, DISM, filesystem repair and hardware procedures remain advice until a tested adapter/procedure is available. This is an explicit safety boundary, not a promise that every diagnostic suggestion has an automatic action.

Quarantine is not a backup and frees no space. Same-volume storage shares the source volume's failure risk. Purge cannot be undone. Recovery also depends on intact files, journals, ownership and access; out-of-band changes, OS reinstall or lost keys may require manual recovery. Do not edit or move the managed storage while an operation is active.

The runtime is not an OS sandbox. A full-shell agent or local administrator can bypass package controls. Approval hashes bind exact plan bytes; they do not authenticate the human. Raw audit reports can contain private paths and metadata. Aggregate exports reduce that information but do not guarantee anonymity.

## Qualification before stable release

Use disposable Windows 10/11 VM snapshots, including ARM64 where available. Verify real Restore Point creation, registry restoration on failure, access denial, file locks, update/reboot states, real cloud placeholders, long/redirected paths and every advertised agent integration. Record the exact source revision, OS build, architecture, PowerShell version and result. Keep unsupported or untested cells explicit.
