#!/usr/bin/env bash
# Interactive helper for encrypting/decrypting/rotating *.sops.yaml files with the homelab age key.
# Usage: ./sops.sh
set -euo pipefail

export SOPS_AGE_KEY_FILE="${SOPS_AGE_KEY_FILE:-$HOME/.homelab-secrets/age/homelab.agekey}"

repo_root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$repo_root"

mapfile -t files < <(find . -name '*.sops.yaml' -not -name '.sops.yaml' -not -path './.git/*' | sort)
if [[ ${#files[@]} -eq 0 ]]; then
  echo "No *.sops.yaml files found." >&2
  exit 1
fi

sync_sops_recipient() {
  local keyfile="$1" pub
  if [[ ! -f "$keyfile" ]]; then
    echo "No such file: $keyfile" >&2
    return 1
  fi
  pub="$(age-keygen -y "$keyfile")"
  if [[ ! "$pub" =~ ^age1 ]]; then
    echo "Could not derive a public key from $keyfile" >&2
    return 1
  fi
  sed -i "s/^\(\s*age:\s*\).*/\1${pub}/" .sops.yaml
  echo "Synced .sops.yaml recipient -> $pub"
}

update_key() {
  local keyfile
  read -rp "Path to private key to sync .sops.yaml from [$SOPS_AGE_KEY_FILE]: " keyfile
  keyfile="${keyfile:-$SOPS_AGE_KEY_FILE}"
  sync_sops_recipient "$keyfile" || exit 1
  echo
  echo "Note: this only updates .sops.yaml's recipient. Existing *.sops.yaml files are still"
  echo "encrypted for the OLD recipient until you run Rotate (or recreate + Encrypt)."
  echo "Key generation itself is homelab-host's job (scripts/init-workstation.sh) — this"
  echo "action never runs age-keygen, it only reads a key that already exists."
}

pick_file() {
  echo "Select a file:" >&2
  select file in "${files[@]}" "All"; do
    [[ -n "${file:-}" ]] && break
    echo "Invalid choice, try again." >&2
  done
  echo "$file"
}

run_one() {
  local f="$1"
  case "$action" in
    Encrypt)
      if grep -q '^sops:' "$f"; then
        echo "Skipping '$f': already looks SOPS-encrypted (found a 'sops:' block)."
        return
      fi
      sops -e -i "$f"
      echo "Encrypted in place: $f"
      ;;
    Decrypt)
      if ! grep -q '^sops:' "$f"; then
        echo "Skipping '$f': no 'sops:' block found — already plaintext on disk?"
        return
      fi
      # Prints to stdout only — never writes plaintext back to disk.
      echo "== $f =="
      sops -d "$f"
      echo
      ;;
  esac
}

encrypt_or_decrypt() {
  local file
  file="$(pick_file)"
  echo
  if [[ "$file" == "All" ]]; then
    for f in "${files[@]}"; do
      run_one "$f"
    done
  else
    run_one "$file"
  fi
}

edit_files() {
  local choice
  while true; do
    echo "Select a file to edit (opens \$EDITOR on the decrypted content, re-encrypts on save):"
    select choice in "${files[@]}" "Done"; do
      if [[ "$choice" == "Done" ]]; then
        return
      elif [[ -n "${choice:-}" ]]; then
        break
      fi
      echo "Invalid choice, try again." >&2
    done
    echo
    if sops "$choice"; then
      echo "Saved: $choice"
    else
      echo "sops exited non-zero for '$choice' — no changes written." >&2
    fi
    echo
  done
}

rotate_have_old_key() {
  local old_key new_key combined f rc

  read -rp "Path to OLD private key [$SOPS_AGE_KEY_FILE]: " old_key
  old_key="${old_key:-$SOPS_AGE_KEY_FILE}"
  read -rp "Path to NEW private key: " new_key

  if [[ ! -f "$old_key" ]]; then
    echo "No such file: $old_key" >&2
    exit 1
  fi
  if [[ ! -f "$new_key" ]]; then
    echo "No such file: $new_key" >&2
    exit 1
  fi

  sync_sops_recipient "$new_key" || exit 1

  local file
  file="$(pick_file)"
  echo

  combined="$(mktemp)"
  chmod 600 "$combined"
  cat "$old_key" "$new_key" > "$combined"
  trap 'rm -f "$combined"' EXIT

  rotate_one() {
    f="$1"
    SOPS_AGE_KEY_FILE="$combined" sops updatekeys --yes "$f"
    if SOPS_AGE_KEY_FILE="$new_key" sops -d "$f" >/dev/null 2>&1; then
      echo "Rotated OK, decrypts with new key alone: $f"
    else
      echo "Rotation may have failed — new key cannot decrypt: $f" >&2
    fi
  }

  if [[ "$file" == "All" ]]; then
    for f in "${files[@]}"; do
      rotate_one "$f"
    done
  else
    rotate_one "$file"
  fi

  rm -f "$combined"
  trap - EXIT

  echo
  echo "Next steps:"
  echo "  1. Move the new key into place: mv $new_key ~/.homelab-secrets/age/homelab.agekey"
  echo "  2. Update the in-cluster secret — homelab-host's flux_bootstrap role only creates"
  echo "     flux-system/sops-age if missing, so delete the old one in-cluster and re-run that"
  echo "     role (or the site playbook) to inject the new key."
  echo "  3. Commit the re-encrypted *.sops.yaml files and the updated .sops.yaml."
}

rotate_lost_old_key() {
  echo
  echo "Assuming homelab-host already generated the new key at the default path."
  sync_sops_recipient "$SOPS_AGE_KEY_FILE" || exit 1
  echo
  echo "Without the old private key, existing ciphertext is permanently unrecoverable —"
  echo "there is nothing to rotate. Recreate each secret from scratch instead:"
  echo

  mapfile -t examples < <(find . -name '*.sops.yaml.example' -not -path './.git/*' | sort)
  if [[ ${#examples[@]} -eq 0 ]]; then
    echo "No *.sops.yaml.example templates found." >&2
    exit 1
  fi

  local ex target confirm
  for ex in "${examples[@]}"; do
    target="${ex%.example}"
    echo "Template: $ex -> $target"
    if [[ -f "$target" ]]; then
      read -rp "  '$target' already exists (old, now-unrecoverable ciphertext) — overwrite with the template? [y/N] " confirm
      [[ "$confirm" == "y" || "$confirm" == "Y" ]] || continue
    fi
    cp "$ex" "$target"
    echo "  Copied. Fill in real values, then run this script again and select Encrypt."
  done
}

echo "Select an operation:"
select action in "Encrypt" "Decrypt" "Edit" "Rotate" "Update Key" "Quit"; do
  case "$action" in
    Encrypt|Decrypt|Edit|Rotate|"Update Key") break ;;
    Quit) exit 0 ;;
    *) echo "Invalid choice, try again." ;;
  esac
done
echo

case "$action" in
  Encrypt|Decrypt)
    encrypt_or_decrypt
    ;;
  Edit)
    edit_files
    ;;
  Rotate)
    echo "Do you still have the OLD private key?"
    select has_old in "Yes" "No"; do
      case "$has_old" in
        Yes) rotate_have_old_key; break ;;
        No) rotate_lost_old_key; break ;;
        *) echo "Invalid choice, try again." ;;
      esac
    done
    ;;
  "Update Key")
    update_key
    ;;
esac
