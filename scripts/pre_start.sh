#!/usr/bin/env bash

export PYTHONUNBUFFERED=1
export APP="SUPIR"
DOCKER_IMAGE_VERSION_FILE="/workspace/${APP}/docker_image_version"

echo "Template version: ${TEMPLATE_VERSION}"

if [[ -e ${DOCKER_IMAGE_VERSION_FILE} ]]; then
    EXISTING_VERSION=$(cat ${DOCKER_IMAGE_VERSION_FILE})
else
    EXISTING_VERSION="0.0.0"
fi

rsync_with_progress() {
    stdbuf -i0 -o0 -e0 rsync -au --info=progress2 "$@" | stdbuf -i0 -o0 -e0 tr '\r' '\n' | stdbuf -i0 -o0 -e0 grep -oP '\d+%|\d+.\d+[mMgG]' | tqdm --bar-format='{l_bar}{bar}' --total=100 --unit='%' > /dev/null
}

sync_apps() {
    # Only sync if the DISABLE_SYNC environment variable is not set
    if [ -z "${DISABLE_SYNC}" ]; then
        # Sync application to workspace to support Network volumes
        echo "Syncing ${APP} to workspace, please wait..."
        rsync_with_progress --remove-source-files /${APP}/ /workspace/${APP}/

        echo "Syncing models to workspace, please wait..."
        rsync_with_progress --remove-source-files /hub/ /workspace/hub/

        echo "${TEMPLATE_VERSION}" > ${DOCKER_IMAGE_VERSION_FILE}
    fi
}

if [ "$(printf '%s\n' "$EXISTING_VERSION" "$TEMPLATE_VERSION" | sort -V | head -n 1)" = "$EXISTING_VERSION" ]; then
    if [ "$EXISTING_VERSION" != "$TEMPLATE_VERSION" ]; then
        sync_apps
    else
        echo "Existing version is the same as the template version, no syncing required."
    fi
else
    echo "Existing version is newer than the template version, not syncing!"
fi

if [[ ${DISABLE_AUTOLAUNCH} ]]
then
    echo "Auto launching is disabled so the application will not be started automatically"
    echo "You can launch it manually:"
    echo ""
    echo "   /start_supir_with_gpu_optimization.sh"
    echo ""
    echo "OR if you have a GPU with a lot of VRAM:"
    echo ""
    echo "   /start_supir.sh"
else
    if [[ ${NO_GPU_OPTIMIZATION} ]]
    then
        /start_supir.sh
    else
        /start_supir_with_gpu_optimization.sh
    fi

    echo "${APP} started"
    echo "Log file: /workspace/logs/supir.log"
fi

echo "All services have been started"
