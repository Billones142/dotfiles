#!/usr/bin/env bash

# Determine the correct fgmod path using XDG directories
if [ -n \"$XDG_DATA_HOME\" ]; then
    FGMOD_PATH=\"$XDG_DATA_HOME/goverlay/fgmod\"
else
    FGMOD_PATH=\"$HOME/.local/share/goverlay/fgmod\"
fi

# Remove fgmod directory if it exists
if [[ -d \"$FGMOD_PATH\" ]]; then
    rm -rf \"$FGMOD_PATH\"
    echo \"FGmod removed from $FGMOD_PATH\"
else
    echo \"FGmod directory not found at $FGMOD_PATH\"
fi
