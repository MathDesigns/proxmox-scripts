#!/usr/bin/env bash
# This script has been modified to point directly to your fork for development.
source <(curl -fsSL https://raw.githubusercontent.com/MathDesigns/proxmox-scripts/main/misc/build.func)

# Copyright (c) 2021-2025 community-scripts ORG
# Author: Gemini & MathDesigns
# License: MIT | https://github.com/community-scripts/ProxmoxVE/raw/main/LICENSE
# Source: https://github.com/hedgedoc/hedgedoc

# --- App Default Values ---
APP="HedgeDoc"
var_tags="${var_tags:-collaboration;markdown}"
var_cpu="${var_cpu:-2}"
var_ram="${var_ram:-2048}"
var_disk="${var_disk:-4}"
var_os="${var_os:-debian}"
var_version="${var_version:-12}"
var_unprivileged="${var_unprivileged:-1}"
export VERBOSE="yes"

# --- Script Functions ---
# The 'header_info' call has been removed to prevent the 404 error on the logo file.
echo -e "      __ _      __         __      \n     / /(_)____/ /  ____  / /_____ \n    / / / / ___/ /  / __ \/ __/ __ \\\n   / /_/ / /  / /__/ /_/ / /_/ /_/ /\n  /____/_/   /____/\\____/\\__/\\____/ \n\n"
echo -e " \033[1;33mThis script will create a new HedgeDoc LXC Container.\033[0m"

variables
color
catch_errors

function update_script() {
  header_info
  check_container_storage
  check_container_resources

  if [[ ! -d /opt/hedgedoc ]]; then
    msg_error "No ${APP} Installation Found!"
    exit
  fi
  
  # Execute the update function within the installer script
  bash /usr/local/bin/hedgedoc-install.sh -u
  exit
}

# --- Main Execution ---
start
build_container
description

msg_ok "Completed Successfully!\n"
echo -e "${CREATING}${GN}${APP} setup has been successfully initialized!${CL}"
echo -e "${INFO}${YW} Access it using the following URL:${CL}"
echo -e "${TAB}${GATEWAY}${BGN}http://${IP}:3000${CL}"
