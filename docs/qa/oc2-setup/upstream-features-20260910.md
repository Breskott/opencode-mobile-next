# Upstream feature check — 2026-09-10 Dubai

Current official sources reviewed while APK work continues. These are upstream release/documentation findings, not an assertion that every feature exists in app-pinned beta18600.

V1 recent changes: GPT6/Astra model discovery for OpenAI subscriptions (1.18.29); longer provider/header and stream timeouts (1.18.27); supportedV2 configuration compatibility (1.18.24); resumable failed subagents and network retries (1.18.20). Source: https://dev.opencode.ai/changelog

V2 documents foreground/background child agents; a command with subagent:true leaves the parent available and reports the child result/failure automatically. Source: https://opencode.ai/v2/docs/commands and https://opencode.ai/v2/docs/agents

V2 local clients share a background server responsible for sessions, permissions and execution. Source: https://opencode.ai/v2/docs/cli

V2 remains beta. Current instructions array is parsed but not applied; AGENTS.md discovery is active. Source: https://opencode.ai/v2/docs/instructions

This checkpoint remains pinned to OC1 1.18.29 and OC2 0.0.0-beta-18600. Mobile integration and real Android setup/history tests are separate from upstream feature availability; provider/model-backed background execution is not asserted by the provider-free runtime smoke.

## Fresh changelog refresh

The official changelog now lists V1 1.18.30, September 9, 2026: GPT-6 Astra system prompt, preserved Bedrock DeepSeek model IDs, Azure/OpenAI SDK compatibility updates, and reasoning variants for supported GitLab GPT/Claude models. The local checkpoint remains pinned to tested V1 1.18.29 and V2 beta-18600; no runtime pin was changed during the final gate. Source: https://dev.opencode.ai/changelog
