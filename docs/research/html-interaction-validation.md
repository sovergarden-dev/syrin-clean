# HTML interaction validation

Start time: 2026-10-30 (Asia/Bangkok).

Initial purpose: continue the remaining quality work after `ea47a07`, focusing on real keyboard behavior, motion controls and narrow layouts without changing OS preferences or treating fixture tests as platform qualification.

## Strategy and checklist

- [x] Inspect the public landing/report artifacts in the supported in-app browser, using synthetic report data only.
- [x] Compare changing-label motion controls with the [W3C button pattern](https://www.w3.org/WAI/ARIA/apg/patterns/button/) (read 2026-10-30).
- [x] Reproduce the incorrect semantics, fix both the shared renderer and landing markup, and verify generated artifacts.
- [x] Exercise cancellation through the public renderer using an isolated synthetic browser contract.
- [x] Run the full local suite and record the actual limits of browser qualification.

## Result and verification

The original motion control combined a changing Pause/Resume action label with `aria-pressed`; the browser exposed it as a checked control, including while it displayed Resume. The shared renderer and landing template now use an ordinary action button. Stage-selection controls retain their valid pressed states. W3C's pattern distinguishes a stable-label toggle from a changing-label action; the fix follows the latter.

Two regressions were observed red then green. The renderer test rejected the old dynamic pressed state. The parsed generated-HTML contract then caught the landing template's remaining static pressed state, which the component-only fixture could not see. Both are now covered at their respective boundaries.

| Check | Evidence and result |
| --- | --- |
| Report keyboard action | Space pauses, Enter resumes; focus stays on the motion button and no pressed state is exposed. |
| Landing keyboard action | The generated landing button has action semantics in EN/VI; pause/resume labels match the action. |
| Narrow layouts | Actual 320 px viewport checked on both pages; visible controls/headings stay within horizontal bounds. Vietnamese profile/tab values remain intact. |
| History keyboard flow | Select Q1, advance to page 2, select Q51, switch VI to EN and prepare a request. Exactly the two observed immutable IDs remain selected and request focus is correct. |
| Prompt tabs | ArrowRight selects/focuses Full prompt; Home returns to Opening message. |
| Offscreen behavior | Scrolling the landing canvas out of view changes its exposed motion state to hidden; its bottom was measured above the viewport. |
| Renderer lifecycle | Controlled timer/frame queues verify cancellation under pause, reduced motion, hidden document, offscreen state and destroy. Destroyed observers/listeners do not restart work. This is synthetic browser-contract evidence. |
| Local regression suite | `tests/run.ps1` exits 0: 65 generated outputs, Node model/renderer tests, 18 quarantine cases, 12 runtime groups, dense 4,098-event fixture and 9 packaging/installation tests. No skipped cases. |

Browser evidence and a screenshot of the corrected Vietnamese control are retained privately. The QA server served only public/synthetic artifacts; the server and owned tabs were closed, and the temporary viewport override was reset.

## Qualification still open

Ctrl+plus did not change the in-app browser viewport or device-pixel ratio; this is not a verified zoom test. Its sibling tabs also kept `document.hidden=false`, so real background-tab visibility is not qualified by that environment. The reduced-motion OS preference was not changed. Screen-reader behavior, actual zoom/system preference transitions, weak-device CPU measurements and broader platform/provider tests remain unverified. The synthetic lifecycle test does not close those gates.

## Decision

Action: keep the corrected action semantics and regression checks, record the [completed local plan](../plan/done/html-qualification.md), and include the fix in the next pre-release. Do not claim complete accessibility or universal background-performance qualification. Reopen when a supported browser/assistive-technology test environment can exercise the remaining real transitions.

Cross-references: [support boundaries](../feat/support.md), [validation commands](../ref/validation.md), [renderer tests](../../tests/report.mjs) and [generated-HTML contracts](../../tests/test_build.py).
