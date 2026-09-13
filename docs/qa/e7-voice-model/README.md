# E7 voice and model controls

Finish line: app-authored voice setup/download/permission/recording/help and model selection/filter/capability/pricing/semantics copy resolves through the active locale; narrow and enlarged RTL layouts retain their controls.

Non-goals: ambient voice, recognizer/native lifecycle changes, provider catalog translation, model/agent renaming, download manifests or checksums, or a partial production Arabic catalog.

Ownership: lib/voice/**, ui/widgets/pickers.dart, model_shortcuts.dart as necessary, new focused tests/captures and localization fragments in this worktree only. Root integrates corpus and other branches.

Plan: inventory visible/helper/manifest copy → localize presentation and typed error summaries without changing wire/technical content → verify existing voice/model behavior and RTL reachability in the serialized heavy slot.

E7-VM-01: picker filters, metadata and helper-built notices bypass localization. E7-VM-02: voice manifest labels/descriptions and support diagnostics are user-facing English. E7-VM-03: voice setup, recording semantics, actions and errors bypass localization. Verification pending.
