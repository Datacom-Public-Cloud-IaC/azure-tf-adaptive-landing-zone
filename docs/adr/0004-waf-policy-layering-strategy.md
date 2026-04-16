# ADR-0004: WAF Policy Layering Strategy

**Status:** Accepted
**Date:** 2026-04-16

## Context

A shared Application Gateway serving 30+ applications creates a WAF management dilemma. A single global WAF policy that's strict enough for the most sensitive app will generate false positives for apps with legitimate edge-case payloads (APIs accepting SQL-like query syntax, CMS platforms with HTML in POST bodies, file upload endpoints). A single global policy that's permissive enough for all apps provides inadequate protection for the ones that need it most.

The WAF must also satisfy compliance requirements (OWASP Top 10 coverage, PII log scrubbing, bot protection) while remaining operationally manageable. The platform team cannot tune WAF rules for 30+ apps they don't understand — app teams must own their exceptions — but app teams shouldn't be able to weaken the baseline below an organisational minimum.

App Gateway v2 supports WAF policy association at three levels: gateway-wide, per-listener, and per-URL path map rule. A policy at a more specific level overrides the less specific one entirely — it's not a merge, it's a replacement. This means a per-listener policy must re-declare the baseline rules it wants to keep, not just add exceptions.

## Decision

WAF is implemented as two layers:

**Layer 1 — Global baseline policy** (gateway-level association):
- OWASP 3.2 managed ruleset in **Detection mode** by default.
- Bot protection enabled with JS challenge for known bot signatures.
- Log scrubbing rules for common PII patterns (credit card numbers, email addresses in request bodies).
- No custom rules — the baseline is purely managed rulesets.
- Owned by the platform team; changes are infrequent and high-ceremony.

**Layer 2 — Per-listener override policies** (optional, declared in app YAML):
- Inherit the same OWASP 3.2 ruleset but with app-specific rule exclusions and mode overrides.
- Can transition individual apps to Prevention mode independently.
- Can add custom rules: rate limiting, geo-blocking, IP allowlisting.
- Can add rule exclusions for specific request fields (e.g., exclude SQL injection checks on a `/api/query` endpoint's request body).
- Owned by the app team; declared in their YAML configuration and validated by JSON Schema.

The transition path for each app: onboard in Detection mode (inheriting the baseline) → analyse WAF logs for false positives → add targeted exclusions in a per-listener policy → switch to Prevention mode for that listener. This happens per-app, not globally.

## Consequences

### Positive
- No app can exist on the gateway without OWASP 3.2 coverage — the baseline is structural, not opt-in.
- App teams tune their own WAF without affecting other apps. A false positive in App A's listener policy doesn't require the platform team to weaken the global baseline.
- Detection-mode default means onboarding never breaks an app. The WAF logs traffic that would be blocked, giving teams data to tune before they commit to enforcement.
- The per-app Detection→Prevention transition creates accountability: each team decides when their exclusions are sufficient, and the WAF logs provide evidence for that decision.

### Negative
- Per-listener policies **replace** the gateway-level policy entirely — they don't merge. This means every per-listener policy must explicitly re-include the OWASP 3.2 managed ruleset, or the app loses baseline protection. The Terraform module handles this by always including the baseline ruleset in generated per-listener policies, but it's a footgun if someone creates a policy manually.
- WAF policies must reside in the same region and subscription as the App Gateway. This prevents sharing a centrally-managed WAF policy library across multiple gateways in different regions — each gateway needs its own copy.
- Detection mode provides visibility but not protection. Apps that never transition to Prevention mode are logging attacks but not stopping them. The platform team needs a dashboard or alerting process to track which apps are still in Detection mode and for how long.

### Trade-offs
- Defaulting to Detection over Prevention prioritises availability over security at onboarding time. For a shared gateway where a false positive in Prevention mode would drop legitimate traffic for a production app the platform team doesn't own, this is the safer default. The organisational goal should be 100% Prevention mode, but the path there is per-app, not per-gateway.
- Allowing per-app rule exclusions means app teams can weaken their own WAF protection. This is bounded by JSON Schema validation (only specific exclusion patterns are allowed, not arbitrary policy modifications) and PR review, but a team that excludes too many rules effectively opts out of WAF. Monitoring exclusion counts per app is a recommended operational practice.

## Alternatives Considered

### Single global WAF policy in Prevention mode
Maximum security posture from day one. All apps get the same protection, no per-app configuration drift. Rejected because a shared gateway serving diverse apps will inevitably encounter false positives — an API endpoint that accepts JSON with SQL-like syntax, a CMS that posts HTML fragments, a webhook receiver with unusual headers. In Prevention mode, these become outages for apps the platform team doesn't control and may not understand. The operational cost of debugging false positives across 30+ apps in Prevention mode exceeds the security benefit versus a structured Detection→Prevention transition.

### Per-app WAF policies with no global baseline
Maximum flexibility — each app defines its entire WAF posture. Rejected because it allows apps to deploy with no WAF protection at all (an empty policy is valid), and the platform team loses the ability to enforce organisational minimums. In a shared gateway, the blast radius of an unprotected app extends beyond that app — a compromised backend can be used as a pivot point for lateral movement.

### Azure Front Door WAF instead of App Gateway WAF
Front Door WAF offers similar managed rulesets with better global edge enforcement and a richer custom rule engine (including rate limiting by client certificate). Rejected as a replacement because the gateway handles private-backend routing that Front Door doesn't reach without Private Link, and running two WAF layers (Front Door + App Gateway) creates rule interaction complexity. For deployments that also use Front Door (see ADR-0003), the recommendation is WAF at Front Door for DDoS and edge filtering, WAF at App Gateway for app-specific rules — but that's a deployment architecture decision, not a module design decision.

### WAF per URL path map rule
App Gateway supports policy association at the URL path map rule level, allowing different WAF rules for different URL paths within the same listener. This is the most granular option. Not rejected outright — the module supports it — but not recommended as the default association level because it dramatically increases the number of WAF policies to manage (one per URL path per app), and most apps don't need path-level WAF differentiation. Available as an advanced option for apps with genuinely distinct WAF requirements per endpoint (e.g., a public API and an admin UI on the same domain).
