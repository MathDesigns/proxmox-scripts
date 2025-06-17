#!/usr/bin/env bash

#
# This is a special debug script to identify which URL is causing the 404 error.
# It will print the commands it would run instead of executing them.
#

echo -e "\n--- URL Debugger Initialized ---\n"

# --- Step 1: Check the URL for the main helper script ('build.func') ---
# This is the first URL your script tries to download.
HELPER_SCRIPT_URL="https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/misc/build.func"
echo "[TESTING] Helper script URL..."
echo "  URL: ${HELPER_SCRIPT_URL}"

if curl -sSL --fail "${HELPER_SCRIPT_URL}" > /dev/null; then
    echo -e "  [SUCCESS] This URL is reachable.\n"
else
    echo -e "  [FAILURE] This URL returned an error. This is likely the first point of failure.\n"
fi


# --- Step 2: Check the URL for the installation script ---
# The helper script (`build.func`) would then try to download the installer.
APP_NAME="hedgedoc"
INSTALL_SCRIPT_URL="https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/install/${APP_NAME}-install.sh"
echo "[TESTING] Application installer script URL..."
echo "  URL: ${INSTALL_SCRIPT_URL}"

if curl -sSL --fail "${INSTALL_SCRIPT_URL}" > /dev/null; then
    echo -e "  [SUCCESS] This URL is reachable.\n"
else
    echo -e "  [FAILURE] This URL returned an error. This is expected, because 'hedgedoc-install.sh' does not exist in the main repository, only in your fork.\n"
fi


# --- Step 3: Check the URLs *inside* the 'hedgedoc-install.sh' script ---
echo "[TESTING] URLs from within the installation script itself..."

# 3a. Check GitHub API URL for HedgeDoc
HEDGEDOC_API_URL="https://api.github.com/repos/hedgedoc/hedgedoc/releases/latest"
echo "  URL: ${HEDGEDOC_API_URL}"
if curl -sSL --fail "${HEDGEDOC_API_URL}" > /dev/null; then
    echo -e "  [SUCCESS] HedgeDoc API is reachable.\n"
else
    echo -e "  [FAILURE] Could not reach the HedgeDoc API.\n"
fi

# 3b. Construct and check the final download URL for the HedgeDoc application
echo "[TESTING] Final application download URL..."
# Using the CORRECTED awk command from our previous diagnosis
LATEST_RELEASE=$(curl -s "$HEDGEDOC_API_URL" | grep "tag_name" | awk '{print substr($2, 2, length($2)-3)}')

if [ -z "$LATEST_RELEASE" ]; then
    echo -e "  [FAILURE] Could not extract the latest release tag from the API.\n"
else
    echo "  [INFO] Extracted release tag: ${LATEST_RELEASE}"
    DOWNLOAD_URL="https://github.com/hedgedoc/hedgedoc/releases/download/${LATEST_RELEASE}/hedgedoc-${LATEST_RELEASE}.tar.gz"
    echo "  URL: ${DOWNLOAD_URL}"
    if curl -sSL --fail --head "${DOWNLOAD_URL}" > /dev/null; then
        echo -e "  [SUCCESS] Application download URL is valid.\n"
    else
        echo -e "  [FAILURE] This final download URL returned an error.\n"
    fi
fi

echo "--- Debugging Complete ---"
echo
echo "SUMMARY:"
echo "The 'FAILURE' messages above indicate which URLs are not being found."
echo "The root cause is that the script is trying to download components from the main 'community-scripts' repository instead of from your 'MathDesigns' fork."
echo "To fix this, you MUST edit the URLs inside the files in your fork ('ct/hedgedoc.sh', 'misc/build.func', and 'misc/install.func') to point to your repository's path during development."
