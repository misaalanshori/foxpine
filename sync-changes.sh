#!/bin/bash
# This script assumes you're currently in the foxpine repo folder
# and your luckfox-pico directory is at the same level as your foxpine repo folder
mkdir -p ../luckfox-pico/output/image
rsync -aHAXv --progress --keep-dirlinks --itemize-changes \
    foxpine/luckfox-pico/ ../luckfox-pico/
rsync -aHAXv --progress --keep-dirlinks --itemize-changes \
    foxpine/sysdrv/ ../luckfox-pico/sysdrv/
rsync -aHAXv --progress --keep-dirlinks --itemize-changes \
    foxpine/project/ ../luckfox-pico/project/
rsync -aHAXv --progress --keep-dirlinks --itemize-changes \
    foxpine/output/image/ ../luckfox-pico/output/image/