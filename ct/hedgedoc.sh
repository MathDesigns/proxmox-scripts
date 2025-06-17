#!/usr/bin/env bash
# Corrected source URL to point to your fork for development
source <(curl -fsSL https://raw.githubusercontent.com/MathDesigns/proxmox-scripts/main/misc/build.func)
# Copyright (c) 2021-2025 community-scripts ORG
# Author: Gemini
# License: MIT | https://github.com/community-scripts/ProxmoxVE/raw/main/LICENSE
# Source: https://github.com/hedgedoc/hedgedoc

# App Default Values
APP="HedgeDoc"
var_tags="${var_tags:-collaboration;markdown}"
var_cpu="${var_cpu:-2}"
var_ram="${var_ram:-2048}"
var_disk="${var_disk:-4}"
var_os="${var_os:-debian}"
var_version="${var_version:-12}"
var_unprivileged="${var_unprivileged:-1}"

header_info "$APP"
variables
color
catch_errors

function update_script() {
  header_info
  check_container_storage
  check_container_resources

  # Check if HedgeDoc installation is present
  if [[ ! -d /opt/hedgedoc ]]; then
    msg_error "No ${APP} Installation Found!"
    exit
  fi

  # Get the latest version from GitHub
  RELEASE=$(curl -s https://api.github.com/repos/hedgedoc/hedgedoc/releases/latest | grep "tag_name" | awk '\''{print substr($2, 2, length($2)-3)}'\'' }')
  
  # Check if an update is required
  if [[ "${RELEASE}" != "$(cat /opt/hedgedoc/version.txt)" ]] || [[ ! -f /opt/hedgedoc/version.txt ]]; then
    msg_info "Stopping ${APP}..."
    systemctl stop hedgedoc
    
    msg_info "Backing up existing installation..."
    mv /opt/hedgedoc "/opt/hedgedoc_backup_$(date +%F_%H-%M-%S)"
    
    msg_info "Updating ${APP} to v${RELEASE}..."
    wget -qO- "https://github.com/hedgedoc/hedgedoc/releases/download/${RELEASE}/hedgedoc-${RELEASE}.tar.gz" | tar -xz -C /opt
    mv /opt/package /opt/hedgedoc

    # Restore config and uploads
    if [ -d "/opt/hedgedoc_backup_$(date +%F_%H-%M-%S)/public/uploads" ]; then
      cp -r "/opt/hedgedoc_backup_$(date +%F_%H-%M-%S)/public/uploads" /opt/hedgedoc/public/
    fi
     if [ -f "/opt/hedgedoc_backup_$(date +%F_%H-%M-%S)/config.json" ]; then
      cp "/opt/hedgedoc_backup_$(date +%F_%H-%M-%S)/config.json" /opt/hedgedoc/
    fi

    (
      cd /opt/hedgedoc
      msg_info "Installing dependencies..."
      ./bin/setup
    )
    
    chown -R hedgedoc:hedgedoc /opt/hedgedoc

    msg_info "Starting ${APP}..."
    systemctl start hedgedoc
    
    echo "${RELEASE}" > /opt/hedgedoc/version.txt
    
    msg_ok "${APP} updated successfully to v${RELEASE}"
  else
    msg_ok "No update required. ${APP} is already at the latest version (v${RELEASE})."
  fi
  exit
}

start
build_container
description

msg_ok "Completed Successfully!\n"
echo -e "${CREATING}${GN}${APP} setup has been successfully initialized!${CL}"
echo -e "${INFO}${YW} Access it using the following URL:${CL}"
echo -e "${TAB}${GATEWAY}${BGN}http://${IP}:3000${CL}"
