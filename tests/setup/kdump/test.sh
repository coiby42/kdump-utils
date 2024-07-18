#!/bin/bash
# vim: dict+=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
. /usr/share/beakerlib/beakerlib.sh || exit 1

rlJournalStart

    rlPhaseStartTest
        rlRun "kdumpctl reset-crashkernel --kernel=ALL"
    rlPhaseEnd

rlJournalEnd
