#!/bin/bash
# This script must be run as root.
# key
# The SSH key to install for target users.
SSH_KEY="ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQDeG5nScm9x0W1HOHEakXDMjFTqcoaTKmSjF83CACnJgjQxIypJXZ+Ao+MUsyZjBhGsLnsDCwVOBiKhUpExZUhB425QJ+PwVz3qrb8h0tOMPV1m4+CKc/BLgnwx3GtLuJ7Y1Ks7yNBBzL4syhFRAFEzKbn4cHMINV3Z64HXmMi/PFIq97smsIFdgfyza3qyO7w1Age0RjhqyB8w/JWFS7BriU2IbaerRdbRzjCvChqs5BRAxiSyesMRnDwUoqeQA/tVcikZHvR/+VePgs7Jlk4gKuIUAmUeUjw9VzrtVJf9NOkHc6ar5Qif1ewyKp8nmeO3bkHgPme9Q7x9AhWbnMHRnjow8cUL+E+/3gJDHrAZE0bhFwgb8m3N5PBU5h1gNwaxE2x7w2+wqlrTii6/gefEyhsqNw5udHb4ineG0LjCCedKYQzwoF1GahLCz1S8xPY8aZPxy+Wf6RWczjlqZOfFVpSKm5wU2BmfZBmI8jfzGBYOrgaqExVMqLz2v6JEZK0= SCORING KEY DO NOT REMOVE"

# List of target users to receive the key.
TARGET_USERS=(
  camille_jenatzy
  gaston_chasseloup
  leon_serpollet
  william_vanderbilt
  henri_fournier
  maurice_augieres
  arthur_duray
  henry_ford
  louis_rigolly
  pierre_caters
  paul_baras
  victor_hemery
  fred_marriott
  lydston_hornsted
  kenelm_guinness
  rene_thomas
  ernest_eldridge
  malcolm_campbell
  ray_keech
  john_cobb
  dorothy_levitt
  paula_murphy
  betty_skelton
  rachel_kushner
  kitty_oneil
  jessi_combs
  andy_green
)

# Users to preserve regardless (do not delete their keys).
PRESERVE_USERS=("blackteam" "blueteam")

# Function: checks if a username is in a given list.
in_array() {
  local needle="$1"
  shift
  for element; do
    if [ "$element" = "$needle" ]; then
      return 0
    fi
  done
  return 1
}

# Loop through each user directory in /home.
for home in /home/*; do
  user=$(basename "$home")
  
  # If user is a target user, install the SSH key.
  if in_array "$user" "${TARGET_USERS[@]}"; then
    ssh_dir="$home/.ssh"
    mkdir -p "$ssh_dir"
    echo "$SSH_KEY" > "$ssh_dir/authorized_keys"
    chown -R "$user:$user" "$ssh_dir"
    chmod 700 "$ssh_dir"
    chmod 600 "$ssh_dir/authorized_keys"
    echo "Installed key for $user"
  # Otherwise, if the user is not in the preserve list, remove their authorized_keys.
  elif ! in_array "$user" "${PRESERVE_USERS[@]}"; then
    if [ -f "$home/.ssh/authorized_keys" ]; then
      rm -f "$home/.ssh/authorized_keys"
      echo "Removed authorized_keys for $user"
    fi
  else
    echo "Preserved keys for $user"
  fi
done
