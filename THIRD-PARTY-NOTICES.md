<!-- Copyright (c) 2026 GitOps Manager, S.L. SPDX-License-Identifier: Apache-2.0 -->
# Third-party software in these images

This repository is Apache 2.0 ([LICENSE](LICENSE)). The images it builds also
contain other people's software, unmodified, each under its own licence.
Versions are the pins in [`images/common/versions.env`](images/common/versions.env)
and the base digest in each Dockerfile; each recipe in
[`images/common/tools/`](images/common/tools/) gives the exact download.

| Component | In | Licence | Source |
|---|---|---|---|
| GitHub Actions runner image (`ghcr.io/actions/actions-runner`) and the runner agent | all images (the base) | MIT | https://github.com/actions/runner |
| Ubuntu 24.04 and its packages | all images (from the base) | various; each package's terms are in `/usr/share/doc/<package>/copyright` in the image | https://ubuntu.com |
| OpenTofu | `runner-workflow-*` | MPL-2.0 | https://github.com/opentofu/opentofu |
| kubectl (Kubernetes) | all images | Apache-2.0 | https://github.com/kubernetes/kubernetes |
| Helm | `runner-workflow-*` | Apache-2.0 | https://github.com/helm/helm |
| kustomize | `runner-workflow-*` | Apache-2.0 | https://github.com/kubernetes-sigs/kustomize |
| yq | all images | MIT | https://github.com/mikefarah/yq |
| crane (go-containerregistry) | `runner-workflow-aws` | Apache-2.0 | https://github.com/google/go-containerregistry |
| AWS CLI v2 | `*-aws` | Apache-2.0 (its bundled components' licences ship in its install folder, `/usr/local/aws-cli`) | https://github.com/aws/aws-cli |
| Azure CLI | `*-azure` | MIT | https://github.com/Azure/azure-cli |
| kubelogin | `*-azure` | MIT | https://github.com/Azure/kubelogin |
| Google Cloud CLI | `*-gcp` | Apache-2.0 (its own terms and bundled components: `/usr/share/google-cloud-sdk/LICENSE`, `/usr/share/doc/google-cloud-cli/copyright`) | https://cloud.google.com/sdk |
| gke-gcloud-auth-plugin | `*-gcp` | Apache-2.0 | https://cloud.google.com/sdk |
| Python 3 | `runner-workflow-*` | PSF-2.0 (Ubuntu package) | https://www.python.org |
| PyYAML | `runner-workflow-*` | MIT (Ubuntu package) | https://github.com/yaml/pyyaml |

**OpenTofu (MPL-2.0):** included unmodified, as released; its source is at the
link above for the version in `versions.env`.

**A fork's own tools** (`images/local/tools/`) are under their own licences:
whoever adds a tool adds its line to their copy of this file.

Nothing here is legal advice; each component's own licence governs it.
