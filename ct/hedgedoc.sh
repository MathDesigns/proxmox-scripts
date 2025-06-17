#!/usr/bin/env bash
#
# IMPORTANT: For development, change the URL below to point to your fork's 'main' branch.
#
# EXAMPLE:
# source <(curl -fsSL https://raw.githubusercontent.com/MathDesigns/proxmox-scripts/main/misc/build.func)
#
source <(curl -fsSL https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/misc/build.func)

# --- App Default Values ---
APP="HedgeDoc"
var_tags="${var_tags:-collaboration;markdown}"
var_cpu="${var_cpu:-2}"
var_ram="${var_ram:-2048}"
var_disk="${var_disk:-4}"
var_os="${var_os:-debian}"
var_version="${var_version:-12}"
var_unprivileged="${var_unprivileged:-1}"
# Enable verbose logging for debugging
export VERBOSE="yes"

# --- Script Functions ---
header_info "$APP"
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
