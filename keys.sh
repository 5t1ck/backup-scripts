k=""
#!/bin/bash
for u in $(ls /home); do
  s="/home/$u/.ssh"
  mkdir -p "$s"
  cat "/home/blueteam/$k" >> "$s/authorized_keys"
  chown -R $u:$u "$s"
  chmod 700 "$s"
  chmod 600 "$s/authorized_keys"
done
