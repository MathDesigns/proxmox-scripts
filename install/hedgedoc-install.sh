#!/usr/bin/env bash
# Copyright (c) 2021-2025 community-scripts ORG
# Author: Gemini
# License: MIT | https://github.com/community-scripts/ProxmoxVE/raw/main/LICENSE
# Source: https://github.com/hedgedoc/hedgedoc

source /dev/stdin <<< "$FUNCTIONS_FILE_PATH"
color
verb_ip6
catch_errors

if [[ "$VERBOSE" == "yes" ]]; then
  set -x
fi

# --- Installation Function ---
function install_hedgedoc() {
  msg_info "Installing Dependencies..."
  $STD apt-get update
  $STD apt-get install -y curl wget gnupg git build-essential python npm
  $STD npm install -g n
  $STD n lts
  $STD npm install -g yarn
  msg_ok "Installed Dependencies."

  msg_info "Installing HedgeDoc..."
  LATEST_RELEASE=$(curl -s https://api.github.com/repos/hedgedoc/hedgedoc/releases/latest | grep "tag_name" | awk '{print substr($2, 2, length($2)-3)}')
  DOWNLOAD_URL="https://github.com/hedgedoc/hedgedoc/releases/download/${LATEST_RELEASE}/hedgedoc-${LATEST_RELEASE}.tar.gz"
  msg_info "Downloading from ${DOWNLOAD_URL}"
  wget -qO- "${DOWNLOAD_URL}" | tar -xz -C /opt
  mv /opt/package /opt/hedgedoc
  echo "${LATEST_RELEASE}" > /opt/hedgedoc/version.txt
  msg_ok "HedgeDoc v${LATEST_RELEASE} Installed."

  msg_info "Creating HedgeDoc User..."
  useradd -r -s /bin/false -d /opt/hedgedoc hedgedoc &>/dev/null
  chown -R hedgedoc:hedgedoc /opt/hedgedoc
  msg_ok "Created HedgeDoc User."

  msg_info "Configuring HedgeDoc..."
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
  msg_ok "Configured HedgeDoc."

  msg_info "Installing HedgeDoc Dependencies (this may take a moment)..."
  (
    cd /opt/hedgedoc
    su -s /bin/bash -c "./bin/setup" hedgedoc
  )
  msg_ok "Installed HedgeDoc Dependencies."

  msg_info "Creating Systemd Service..."
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
  msg_ok "Created Systemd Service."
}

# --- Update Function ---
function update_hedgedoc() {
    msg_info "Stopping HedgeDoc service..."
    systemctl stop hedgedoc

    msg_info "Backing up HedgeDoc configuration and uploads..."
    if [ -d "/opt/hedgedoc" ]; then
        mv /opt/hedgedoc "/opt/hedgedoc_backup_$(date +%F_%H-%M-%S)"
    fi
    
    install_hedgedoc

    if [ -d "/opt/hedgedoc_backup_$(date +%F_%H-%M-%S)" ]; then
        msg_info "Restoring configuration and uploads..."
        if [ -f "/opt/hedgedoc_backup_$(date +%F_%H-%M-%S)/config.json" ]; then
            cp "/opt/hedgedoc_backup_$(date +%F_%H-%M-%S)/config.json" /opt/hedgedoc/
        fi
        if [ -d "/opt/hedgedoc_backup_$(date +%F_%H-%M-%S)/public/uploads" ]; then
            cp -r "/opt/hedgedoc_backup_$(date +%F_%H-%M-%S)/public/uploads" /opt/hedgedoc/public/
        fi
        chown -R hedgedoc:hedgedoc /opt/hedgedoc
    fi

    msg_info "Starting HedgeDoc service..."
    systemctl start hedgedoc
    msg_ok "Update complete."
}

# --- Main Logic ---
if [ "$1" == "-u" ]; then
    update_hedgedoc
    exit
fi

setting_up_container
network_check
install_hedgedoc
motd_ssh
customize

msg_info "Cleaning up..."
$STD apt-get -y autoremove
$STD apt-get -y autoclean
msg_ok "Cleaned."
