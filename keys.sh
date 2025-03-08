#!/bin/bash
# This script must be run as root.
# key
# The SSH key to install for target users.
SSH_KEY="ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQCcM4aDj8Y4COv+f8bd2WsrIynlbRGgDj2+q9aBeW1Umj5euxnO1vWsjfkpKnyE/ORsI6gkkME9ojAzNAPquWMh2YG+n11FB1iZl2S6yuZB7dkVQZSKpVYwRvZv2RnYDQdcVnX9oWMiGrBWEAi4jxcYykz8nunaO2SxjEwzuKdW8lnnh2BvOO9RkzmSXIIdPYgSf8bFFC7XFMfRrlMXlsxbG3u/NaFjirfvcXKexz06L6qYUzob8IBPsKGaRjO+vEdg6B4lH1lMk1JQ4GtGOJH6zePfB6Gf7rp31261VRfkpbpaDAznTzh7bgpq78E7SenatNbezLDaGq3Zra3j53u7XaSVipkW0S3YcXczhte2J9kvo6u6s094vrcQfB9YigH4KhXpCErFk08NkYAEJDdqFqXIjvzsro+2/EW1KKB9aNPSSM9EZzhYc+cBAl4+ohmEPej1m15vcpw3k+kpo1NC2rwEXIFxmvTme1A2oIZZBpgzUqfmvSPwLXF0EyfN9Lk= SCORING KEY DO NOT REMOVE"

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
