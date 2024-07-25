#!/bin/bash
# vim: dict+=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
. /usr/share/beakerlib/beakerlib.sh || exit 1

SYSRQ_REBOOT=/var/tmp/configure-kernel-SYSRQ-reboot

rlJournalStart

  if [ ! -e $CRASHKERNLE_REBOOT ]; then

  if [ ! -e $SYSRQ_REBOOT ]; then
    rlPhaseStartTest
        rlRun "touch $SYSRQ_REBOOT"
        rlRun "kdumpctl restart"
        # Without sync, $SYSRQ_REBOOT may not be written to the disk
        # And this test will be executed infinitely
        rlRun "sync"
        rlRun "echo 1 > /proc/sys/kernel/sysrq"
        tmt-reboot -c "echo c > /proc/sysrq-trigger"
    rlPhaseEnd

  else
    rlPhaseStartCleanup
        rlRun "rm -f $SYSRQ_REBOOT"
    rlPhaseEnd
  fi
rlJournalEnd
