#!/usr/bin/env bash
# Copyright (c) 2021-2025 community-scripts ORG
# This is a self-contained script for creating a HedgeDoc LXC container.
# All necessary functions are included here to avoid external calls.

# --- Embedded Functions ---
msg_info() { echo -e "\n[INFO] $1"; }
msg_ok() { echo -e "[OK] $1"; }
msg_error() { echo -e "\n[ERROR] $1" >&2; }

# --- Main Script Logic ---
# Get the next available VM/CT ID from Proxmox
msg_info "Searching for the next available CT ID..."
if ! NEXTID=$(pvesh get /cluster/nextid); then
    msg_error "Could not get next available CT ID from pvesh."
    exit 1
fi
msg_ok "Found next available CT ID: ${NEXTID}"

# Create the HedgeDoc LXC Container
msg_info "Creating HedgeDoc LXC container..."
pct create $NEXTID local:vztmpl/debian-12-standard_12.2-1_amd64.tar.zst \
    --hostname hedgedoc \
    --cores 2 \
    --memory 2048 \
    --swap 512 \
    --rootfs local-lvm:4 \
    --net0 name=eth0,bridge=vmbr0,ip=dhcp \
    --onboot 1 \
    --unprivileged 1 \
    --start 1

if [ $? -ne 0 ]; then
    msg_error "Failed to create HedgeDoc LXC container."
    exit 1
fi
msg_ok "HedgeDoc container created with ID ${NEXTID}."

# Wait a few seconds for the container to initialize its network
msg_info "Waiting for container to start and get an IP address..."
sleep 8

# The installation script to be run inside the container
INSTALL_SCRIPT='
#!/usr/bin/env bash
set -e
export DEBIAN_FRONTEND=noninteractive

# --- Installation ---
echo "--- Starting HedgeDoc Installation Inside Container ---"

echo "Updating package lists..."
apt-get update >/dev/null

echo "Installing dependencies..."
apt-get install -y curl wget gnupg git build-essential python npm >/dev/null

echo "Installing latest Node.js and Yarn..."
npm install -g n >/dev/null
n lts >/dev/null
npm install -g yarn >/dev/null

echo "Downloading and extracting HedgeDoc..."
LATEST_RELEASE=$(curl -s https://api.github.com/repos/hedgedoc/hedgedoc/releases/latest | grep "tag_name" | awk '\''{print substr($2, 2, length($2)-3)}'\'')
wget -qO- "https://github.com/hedgedoc/hedgedoc/releases/download/${LATEST_RELEASE}/hedgedoc-${LATEST_RELEASE}.tar.gz" | tar -xz -C /opt
mv /opt/package /opt/hedgedoc
echo "${LATEST_RELEASE}" > /opt/hedgedoc/version.txt

echo "Creating HedgeDoc user..."
useradd -r -s /bin/false -d /opt/hedgedoc hedgedoc
chown -R hedgedoc:hedgedoc /opt/hedgedoc

echo "Configuring HedgeDoc..."
cat <<EOF > /opt/hedgedoc/config.json
{
  "production": {
    "db": {
      "dialect": "sqlite",
      "storage": "/opt/hedgedoc/db.hedgedoc.sqlite"
    },
    "urlAddPort": true,
    "domain": "localhost"
  }
}
EOF
chown hedgedoc:hedgedoc /opt/hedgedoc/config.json

echo "Installing HedgeDoc npm dependencies (this may take a moment)..."
(
  cd /opt/hedgedoc
  su -s /bin/bash -c "./bin/setup" hedgedoc
) >/dev/null

echo "Creating Systemd service..."
cat <<EOF > /etc/systemd/system/hedgedoc.service
[Unit]
Description=HedgeDoc - Collaborative Markdown Editor
After=network.target

[Service]
Type=simple
User=hedgedoc
Group=hedgedoc
WorkingDirectory=/opt/hedgedoc
ExecStart=/usr/local/bin/node /opt/hedgedoc/app.js
Restart=always

[Install]
WantedBy=multi-user.target
EOF
systemctl enable -q --now hedgedoc

echo "Cleaning up..."
apt-get autoremove -y >/dev/null
apt-get autoclean >/dev/null

echo "--- HedgeDoc Installation Complete ---"
'

# Push the installation script to the container and execute it
msg_info "Pushing installation script to the container..."
pct push $NEXTID <(echo "$INSTALL_SCRIPT") /tmp/install-hedgedoc.sh -p /tmp/install-hedgedoc.sh
msg_ok "Installation script pushed."

msg_info "Running installation script inside the container..."
if ! pct exec $NEXTID -- bash /tmp/install-hedgedoc.sh; then
    msg_error "HedgeDoc installation failed. Please check the container's console."
    exit 1
fi
msg_ok "Installation script finished."


# Get container IP
while [ -z "$IP" ]; do
  IP=$(pct exec $NEXTID ip -4 addr show eth0 | grep -oP '(?<=inet\s)\d+(\.\d+){3}')
  [ -z "$IP" ] && sleep 1
done


# Final confirmation message
msg_ok "Deployment successful!"
echo -e "You can access HedgeDoc at: ${BLU}http://${IP}:3000${CL}"
