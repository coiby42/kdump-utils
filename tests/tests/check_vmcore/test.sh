#!/bin/sh -eux
MAX_WAIT_TIME=300
_waited=0
while [ $_waited -le $MAX_WAIT_TIME ]; do
    if ls $VMCORE_PATH/*/vmcore &> /dev/null; then
        echo "Vmcore found!"
        exit 0
    fi
    _waited=$((_waited+1))
done

echo "No Vmcore found!" 1>&2
exit 1
