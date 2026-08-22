# hardened-calico

[![License: Apache 2.0](https://img.shields.io/github/license/octivi/hardened-calico)](https://choosealicense.com/licenses/apache-2.0/)
[![Conventional Commits](https://img.shields.io/badge/Conventional%20Commits-1.0.0-yellow.svg)](https://conventionalcommits.org/)
[![Semantic Versioning](https://img.shields.io/badge/SemVer-2.0.0-blue)](https://semver.org/spec/v2.0.0.html)

`ghcr.io/octivi/hardened-calico` is a minimal derivative of Rancher's
[`rancher/hardened-calico`](https://github.com/rancher/image-build-calico) image. It replaces only
the statically linked `/usr/sbin/nft` binary with the version built and released by
[`octivi/k3s-root`](https://github.com/octivi/k3s-root).

The Calico binaries, configuration, entrypoints, and all other userspace tools remain unchanged from
the pinned Rancher base image.

Currently, only the `amd64` architecture is supported.

## Versioning

All inputs are pinned in [`versions.env`](versions.env):

- the `octivi/k3s-root` release and SHA-256 of its amd64 archive;
- the Rancher Calico image tag and immutable digest;
- the expected nftables version;
- the output image tag.

Octivi releases use the following format for both repositories:

```text
v<upstream-version>-octivi.<revision>
```

For example:

```text
k3s-root: v0.15.2-octivi.1
hardened-calico: v3.32.1-build20260722-octivi.1
```

## Prepare the k3s-root release

The release in `octivi/k3s-root` must contain `k3s-root-amd64.tar`. Record its checksum before
updating `versions.env`:

```console
sha256sum dist/k3s-root-amd64.tar
```

The archive is downloaded during the build and is never committed to this repository.

## Pin the Rancher base image

Resolve the digest of the selected base image:

```console
docker buildx imagetools inspect \
  rancher/hardened-calico:v3.32.1-build20260722
```

Store the complete `sha256:...` digest in `versions.env`.

## Local build

Requirements:

- Docker with BuildKit;
- GitHub CLI authenticated for access to `octivi/k3s-root`;
- GNU Make and `sha256sum`.

Build and verify the image:

```console
make test
```

Publish it manually if needed:

```console
docker login ghcr.io
make push
```

## Automated publication

The GitHub Actions workflow publishes `linux/amd64` images to GHCR. It runs when a matching Git tag
is pushed or when manually dispatched. For tag builds, the Git tag must equal `IMAGE_TAG` from
`versions.env`.

If `octivi/k3s-root` is private, the default token of this repository cannot read releases from that
sibling repository. Configure a GitHub App or a fine-grained token with `Contents: read`, then use
it as `GH_TOKEN` in the download step.

## RKE2 configuration

Override all Calico image references to keep the node, CNI, FlexVolume, and optional controller
components on the same pinned build. The Flannel image remains managed by the RKE2 chart because it
is a separate component:

```yaml
apiVersion: helm.cattle.io/v1
kind: HelmChartConfig
metadata:
  name: rke2-canal
  namespace: kube-system
spec:
  valuesContent: |-
    calico:
      cniImage:
        repository: ghcr.io/octivi/hardened-calico
        tag: v3.32.1-build20260722-octivi.1
      nodeImage:
        repository: ghcr.io/octivi/hardened-calico
        tag: v3.32.1-build20260722-octivi.1
      flexvolImage:
        repository: ghcr.io/octivi/hardened-calico
        tag: v3.32.1-build20260722-octivi.1
      kubeControllerImage:
        repository: ghcr.io/octivi/hardened-calico
        tag: v3.32.1-build20260722-octivi.1
```

Place the manifest at:

```text
/var/lib/rancher/rke2/server/manifests/rke2-canal-config.yaml
```

After RKE2 reconciles the Helm chart, verify the rollout:

```console
kubectl rollout status daemonset/rke2-canal \
  --namespace kube-system \
  --timeout=300s

kubectl get daemonset rke2-canal \
  --namespace kube-system \
  --output=jsonpath='{range .spec.template.spec.initContainers[*]}init/{.name}={.image}{"\n"}{end}{range .spec.template.spec.containers[*]}container/{.name}={.image}{"\n"}{end}'
```

## Support and licensing

This is a custom image and is outside the stock SUSE Rancher support matrix. Keep the original image
tag available for rollback and reproduce issues on the stock image before opening a vendor support
request.

The repository automation is licensed under Apache-2.0. The resulting image contains components
under their respective upstream licenses, including Calico and GPL-2.0-licensed nftables.
Corresponding nftables build inputs and source references are maintained in `octivi/k3s-root`.
