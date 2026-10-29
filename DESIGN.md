# Syrin clean visual system

> updated 2026-10-29 · preview work following the imported v3.6 distribution

The visual idea is a field instrument for making deliberate choices: warm paper for explanations, dark ink for the review lens, and the existing green identity for actions and selected states. The landing is a discovery/configuration surface; the report is a reading and operating surface.

Use Bricolage Grotesque for landing display headings and Be Vietnam Pro for readable bilingual content and report controls. Self-host and embed the licensed font subsets. Shared color, spacing, focus, typography and motion tokens live in `src/shared/tokens.css`; report and landing styles consume them. Code uses the system monospace stack as a limited outlier role.

The landing's authored moment is a review lens that moves abstract file marks from inspection to an explicit selection and recovery state. It explains the workflow and never pretends to scan the visitor's PC. Supporting content has visible static defaults, native controls and short state feedback. No repeated scroll reveals, card tilts or decorative counters.

The report puts provenance, unknown/partial states and measured values first. Its optional spatial view uses actual report categories and has an equivalent labeled table. History keeps full item IDs, selection across pages/filters and clear state labels. A language change preserves the current work.

Motion is confined to one canvas per surface with at most 280 points, or 160 when initialized at a narrow viewport. Automatic drawing is capped at 24 fps; direct pointer manipulation is coalesced into animation frames. The automatic loop stops offscreen, in a hidden tab and when paused. Reduced motion starts with a deliberate static frame. Forms and report content remain usable without any animation. Print produces a readable summary, not a claim that a paginated screen contains the entire journal.

Every control has visible keyboard focus and a clear label. Mobile reorders the primary task before artwork, uses native selects and allows data tables to scroll within their own region. Long Vietnamese labels and private file paths must wrap without clipping. The public page uses no analytics or report upload.
