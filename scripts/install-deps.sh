#!/usr/bin/env bash
# Installs this repo's local validation toolchain into a user-writable bin dir (no sudo).
#
# Self-contained on purpose: it does NOT read from or depend on the homelab-host repo. Even
# where homelab-host installs some of the same tools, they are duplicated here because a
# different repo on a different workstation must be able to validate this GitOps tree on its
# own. Running it twice is safe (idempotent).
#
# Usage:
#   ./scripts/install-deps.sh                # install any missing tools into ~/.local/bin
#   ./scripts/install-deps.sh --force        # (re)install every tool into ~/.local/bin
#   ./scripts/install-deps.sh --check        # only report what is installed, install nothing
#   INSTALL_DIR=~/bin ./scripts/install-deps.sh
#
# Tool versions are pinned below for reproducibility; override any of them via env, e.g.
#   KUSTOMIZE_VERSION=v5.5.0 ./scripts/install-deps.sh
set -euo pipefail

INSTALL_DIR="${INSTALL_DIR:-$HOME/.local/bin}"

# Pinned versions — bump these deliberately, then re-run. kubectl tracks upstream "stable".
KUSTOMIZE_VERSION="${KUSTOMIZE_VERSION:-v5.4.3}"
KUBECONFORM_VERSION="${KUBECONFORM_VERSION:-v0.6.7}"
SOPS_VERSION="${SOPS_VERSION:-v3.9.1}"
AGE_VERSION="${AGE_VERSION:-v1.2.0}"
FLUX_VERSION="${FLUX_VERSION:-2.3.0}"   # flux release assets omit the leading "v"
YQ_VERSION="${YQ_VERSION:-v4.44.3}"

force=0
check_only=0
for arg in "$@"; do
  case "$arg" in
    --force) force=1 ;;
    --check) check_only=1 ;;
    -h|--help) grep '^#' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "Unknown argument: $arg" >&2; exit 2 ;;
  esac
done

os="$(uname -s | tr '[:upper:]' '[:lower:]')"
case "$(uname -m)" in
  x86_64|amd64) arch=amd64 ;;
  aarch64|arm64) arch=arm64 ;;
  *) echo "Unsupported architecture: $(uname -m)" >&2; exit 1 ;;
esac
if [[ "$os" != "linux" && "$os" != "darwin" ]]; then
  echo "Unsupported OS: $os" >&2; exit 1
fi

have() { command -v "$1" >/dev/null 2>&1; }

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

# fetch <url> <dest> — download over HTTPS, failing loudly on HTTP errors.
fetch() {
  echo "  fetching $1"
  curl -fsSL "$1" -o "$2"
}

# Decide whether to (re)install a tool. Skips present tools unless --force.
want() {
  local cmd="$1"
  if (( check_only )); then return 1; fi
  if have "$cmd" && (( ! force )); then
    echo "== $cmd: already present ($(command -v "$cmd")) — skipping (use --force to reinstall)"
    return 1
  fi
  return 0
}

install_kustomize() {
  want kustomize || return 0
  echo "== kustomize $KUSTOMIZE_VERSION"
  fetch "https://github.com/kubernetes-sigs/kustomize/releases/download/kustomize/${KUSTOMIZE_VERSION}/kustomize_${KUSTOMIZE_VERSION}_${os}_${arch}.tar.gz" "$tmp/kustomize.tgz"
  tar -xzf "$tmp/kustomize.tgz" -C "$tmp" kustomize
  install -m 0755 "$tmp/kustomize" "$INSTALL_DIR/kustomize"
}

install_kubeconform() {
  want kubeconform || return 0
  echo "== kubeconform $KUBECONFORM_VERSION"
  fetch "https://github.com/yannh/kubeconform/releases/download/${KUBECONFORM_VERSION}/kubeconform-${os}-${arch}.tar.gz" "$tmp/kubeconform.tgz"
  tar -xzf "$tmp/kubeconform.tgz" -C "$tmp" kubeconform
  install -m 0755 "$tmp/kubeconform" "$INSTALL_DIR/kubeconform"
}

install_sops() {
  want sops || return 0
  echo "== sops $SOPS_VERSION"
  fetch "https://github.com/getsops/sops/releases/download/${SOPS_VERSION}/sops-${SOPS_VERSION}.${os}.${arch}" "$tmp/sops"
  install -m 0755 "$tmp/sops" "$INSTALL_DIR/sops"
}

install_age() {
  want age || return 0
  echo "== age $AGE_VERSION (age + age-keygen)"
  fetch "https://github.com/FiloSottile/age/releases/download/${AGE_VERSION}/age-${AGE_VERSION}-${os}-${arch}.tar.gz" "$tmp/age.tgz"
  tar -xzf "$tmp/age.tgz" -C "$tmp"
  install -m 0755 "$tmp/age/age" "$INSTALL_DIR/age"
  install -m 0755 "$tmp/age/age-keygen" "$INSTALL_DIR/age-keygen"
}

install_flux() {
  want flux || return 0
  echo "== flux $FLUX_VERSION"
  fetch "https://github.com/fluxcd/flux2/releases/download/v${FLUX_VERSION}/flux_${FLUX_VERSION}_${os}_${arch}.tar.gz" "$tmp/flux.tgz"
  tar -xzf "$tmp/flux.tgz" -C "$tmp" flux
  install -m 0755 "$tmp/flux" "$INSTALL_DIR/flux"
}

install_kubectl() {
  want kubectl || return 0
  local stable
  stable="$(curl -fsSL https://dl.k8s.io/release/stable.txt)"
  echo "== kubectl $stable (upstream stable)"
  fetch "https://dl.k8s.io/release/${stable}/bin/${os}/${arch}/kubectl" "$tmp/kubectl"
  install -m 0755 "$tmp/kubectl" "$INSTALL_DIR/kubectl"
}

install_yq() {
  want yq || return 0
  echo "== yq $YQ_VERSION"
  fetch "https://github.com/mikefarah/yq/releases/download/${YQ_VERSION}/yq_${os}_${arch}" "$tmp/yq"
  install -m 0755 "$tmp/yq" "$INSTALL_DIR/yq"
}

if (( ! check_only )); then
  mkdir -p "$INSTALL_DIR"
  echo "Installing validation toolchain into $INSTALL_DIR (os=$os arch=$arch)"
  echo
  install_kustomize
  install_kubeconform
  install_sops
  install_age
  install_flux
  install_kubectl
  install_yq
  echo
fi

# yamllint is a Python package, not a static binary — cannot install it here without pip/sudo.
if ! have yamllint; then
  echo "NOTE: yamllint is not installed. It is optional for structural validation; install with"
  echo "      one of:  pipx install yamllint   |   pip install --user yamllint"
  echo
fi

echo "Installed tool versions:"
report() {
  if have "$1"; then
    printf '  %-12s %s\n' "$1" "$("${@:2}" 2>&1 | head -n1)"
  else
    printf '  %-12s MISSING\n' "$1"
  fi
}
report kustomize   kustomize version
report kubeconform kubeconform -v
report sops        sops --version
report age         age --version
report flux        flux --version
report kubectl     kubectl version --client
report yq          yq --version
report yamllint    yamllint --version

echo
case ":$PATH:" in
  *":$INSTALL_DIR:"*) : ;;
  *) echo "WARNING: $INSTALL_DIR is not on your PATH. Add it, e.g.:"
     echo "         export PATH=\"$INSTALL_DIR:\$PATH\"" ;;
esac
