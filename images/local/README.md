<!-- Copyright (c) 2026 GitOps Manager, S.L. SPDX-License-Identifier: Apache-2.0 -->
# local/: a fork's own

This repo never writes anything here except this file, so what a fork puts
here never conflicts with "Sync fork".

| Put | For |
|---|---|
| `local/tools/<tool>.tool` | Your tool recipes (format: [`../common/tools/README.md`](../common/tools/README.md)). Same name as one of ours replaces ours, and the build log says so. |
| `local/versions.env` | Your pins, read after ours. |
| `local/build/action.yml` | Your build, used when `BUILD_IMAGE=local`: copy [`examples/build/action.yml`](../../examples/build/action.yml) here and change it. |

Then name your tools in an image's `tools.local` (beside its `tools`), or in
your own image's `tools`. The repo README's "Your own images" walks through it.
