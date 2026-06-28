# Veera — Threat Model

First-pass threat model for Veera, a personal iOS habit tracker. Written as a
portfolio artifact and to guide the security work still on the roadmap.

Veera is **deliberately small in attack surface**: local-only, no network,
no accounts, no cloud sync, no third-party Swift packages. This model exists
to document that explicitly, identify the residual risks, and name the
mitigations already in place versus still pending.

Revisit this document when any of the following change:
- A network/server component is added (sync, telemetry, AI).
- A third-party Swift package is added.
- Distribution moves from sideload to TestFlight or the App Store.
- The biometric gate is implemented (M1 below).

## 1. Assets

| ID | Asset | Sensitivity | Where it lives |
| -- | ----- | ----------- | -------------- |
| A1 | Habit / task / reminder content (titles, notes, deadlines) | Low–medium. Possibly reveals routines, schedules, personal goals. | SwiftData store inside the app sandbox. |
| A2 | XP / level / streak / stat progression | Low. Reveals usage cadence. | Same SwiftData store. |
| A3 | Scheduled local notifications | Low. Same content as A1; visible on the lock screen if not configured otherwise. | `UNUserNotificationCenter` queue. |
| A4 | App binary + signing identity | Low. Free signing; no enterprise cert to abuse. | Device. |

No PII beyond a freely-edited display name. No credentials. No tokens.

## 2. Adversaries

| ID | Adversary | Capability | Plausible motive |
| -- | --------- | ---------- | ---------------- |
| ADV1 | Physical attacker with the unlocked device | Read/write the app's data via UI; not file-system access. | Curiosity, snooping. |
| ADV2 | Physical attacker with a locked device | Limited — iOS data protection encrypts at rest while locked. | Theft / forensic recovery. |
| ADV3 | Malicious sideloaded app on the same device | iOS app sandbox prevents direct cross-app reads; can target shared surfaces (clipboard, photos picker if granted). | Profiling / data exfiltration. |
| ADV4 | Jailbroken device or attacker with root | Bypasses iOS data protection while passcode known. | Targeted compromise. |
| ADV5 | Toolchain / supply-chain compromise | Hostile compiler, hostile Xcode plugin, hostile MCP tool. | Inject malicious code at build time. |
| ADV6 | Future self — accidental data loss | Deletes the app; loses local data. | Carelessness. |

App Store reviewers / advertising networks / analytics SDKs are not in scope
because none are present.

## 3. Threats

| ID | Threat | Adversary | STRIDE |
| -- | ------ | --------- | ------ |
| T1 | Read habit/task content from an unlocked phone left unattended. | ADV1 | Information disclosure |
| T2 | Recover SwiftData store from a locked device via forensic tooling. | ADV2 | Information disclosure |
| T3 | Malicious sideloaded app reads Veera's container via missing sandbox guarantees. | ADV3 | Information disclosure |
| T4 | Notification preview leaks habit/task titles on the lock screen. | ADV1, ADV2 | Information disclosure |
| T5 | Jailbreak escalates ADV2 into ADV4 and reads the on-disk SwiftData file. | ADV4 | Information disclosure / tampering |
| T6 | Toolchain compromise injects code into the signed app at build time. | ADV5 | Tampering / elevation |
| T7 | App deletion or device wipe loses all habit/streak history (no backup). | ADV6 | Loss of availability |
| T8 | Future feature adds a network call without review and exfiltrates data. | (regression) | Information disclosure |

Threats deliberately **out of scope** for this version:
- Authentication / authorization bypass (no auth surface).
- Network attacks (no network).
- CSRF / XSS / SQLi (no web).
- Replay or token theft (no tokens).

## 4. Mitigations

| ID | Mitigation | Status | Addresses |
| -- | ---------- | ------ | --------- |
| M1 | Trust boundary = device passcode + iOS data protection (no separate app-level biometric gate). | **Shipped 2026-06-07.** Intentional design: the in-app gate added friction without meaningful protection beyond what M2 already provides. The phone passcode is the trust boundary; the `@AppStorage("veera.onboardingCompleted")` flag controls *first-run UX*, not *security*. Revisit if Veera ever holds higher-sensitivity content. | T1, T4 (in combination with M2 and M4) |
| M2 | iOS data protection at rest; require device passcode. | Inherited from iOS. Relies on user setting a passcode. | T2 |
| M3 | iOS app sandbox isolates Veera's container from other apps. | Inherited from iOS. | T3 |
| M4 | Hide reminder title/body on the lock screen — schedule the notification with a generic title (`"Veera"`) and body (`"A quest awaits."`), carry the real content in `userInfo` for the in-app handler. | **Mitigated 2026-06-07.** Toggleable via Settings → Lock Screen Privacy (`@AppStorage("veera.hideLockScreenContent")`), default-on. Toggling the flag re-schedules all active reminders so existing requests honor the new setting. `NotificationDelegate` handles foreground delivery and returns `[.banner, .sound, .list]` so iOS still surfaces the notification with whatever content was scheduled. | T4 |
| M5 | No jailbreak mitigation. Accept residual risk. | Accepted. Add jailbreak detection only if scope changes. | T5 |
| M6 | Pin Xcode / Swift version in `.github/workflows/ci.yml`. Future: gitleaks pre-commit, Dependabot (no current deps, runs as guardrail). | **In progress** — CI pinned, gitleaks/Dependabot still to add. | T6 |
| M7 | Trust the Apple toolchain. SBOM / reproducible builds are out of scope for a personal app. | Accepted. | T6 |
| M8 | Rely on iCloud device-level backup for resilience. Document this. | Accepted; documented here. | T7 |
| M9 | Threat model gate: any new network call, third-party SDK, or external storage gets a row in §3 before merge. | This document. | T8 |
| M10 | HealthKit scope. Read-only access to `stepCount`, `sleepAnalysis`, `mindfulSession`, `workoutType` only. Day-level summaries materialise into XP and a `HealthImportLedger` UUID; raw samples never persist. Permission is opt-in per source via Settings. No network egress. | **Shipped 2026-06-09.** | Information disclosure regression (would only matter if data left the device). |
| M11 | EventKit scope. One-way push only — Veera writes habit reminders / task deadlines / standalone reminders into a dedicated "Veera" calendar & list, identified by `EKItem.identifier` stored on the Veera model. Deletes in Veera delete the mirror; deletes outside Veera have no callback into Veera. Opt-in per direction via Settings. | **Shipped 2026-06-09.** | Information disclosure (lock-screen / Calendar surface) — same toggleable trade-off as M4. |

## 5. Risk register / accepted

| Risk | Decision |
| ---- | -------- |
| No app-level authentication. | Accepted (M1 shipped as the explicit choice — device passcode is the trust boundary). |
| No backup independent of iCloud device backup. | Accepted. Single user, low blast radius. |
| Notifications can leak content when the privacy toggle is OFF. | Accepted; surfaced in Settings so the user owns the trade-off. |
| Sideloaded distribution bypasses App Store review. | Accepted — personal use, code authored by the user. |
| No SBOM / no supply-chain scanning beyond what Apple provides. | Accepted — no third-party deps to scan. |

## 6. Verification

How we know mitigations actually hold:
- M1 / M4: SwiftUI snapshot tests + manual QA on the device after each release.
- M6: `.github/workflows/ci.yml` builds and tests on each push.
- M9: PRs that touch `App/`, `Services/`, or `Models/` should include a one-line note in the PR description on whether this document needs an update.

## 7. Revision history

| Date | Change |
| ---- | ------ |
| 2026-06-04 | Initial threat model written. |
| 2026-06-06 | M1 re-evaluated and intentionally dropped (device passcode is the trust boundary). |
| 2026-06-07 | M1 re-stated as "shipped — explicit choice". M4 mitigated via generic-content scheduling + Settings privacy toggle (`veera.hideLockScreenContent`, default on). |
| 2026-06-09 | M10 added (HealthKit read-only auto-XP, on-device). M11 added (EventKit one-way push, opt-in). |
