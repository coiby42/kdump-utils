#!/bin/bash
# vim: dict+=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
. /usr/share/beakerlib/beakerlib.sh || exit 1

function get_IP() {
    if echo $1 | grep -E -q '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+'; then
        echo $1
    else
        host $1 | sed -n -e 's/.*has address //p' | head -n 1
    fi
}

function assign_server_roles() {
    if [ -n "${TMT_TOPOLOGY_BASH}" ] && [ -f ${TMT_TOPOLOGY_BASH} ]; then
        # assign roles based on tmt topology data
        cat ${TMT_TOPOLOGY_BASH}
        . ${TMT_TOPOLOGY_BASH}

        export CLIENT=${TMT_GUESTS["client.hostname"]}
        export SERVER=${TMT_GUESTS["server.hostname"]}
        MY_IP="${TMT_GUEST['hostname']}"
    elif [ -n "$SERVERS" ]; then
        # assign roles using SERVERS and CLIENTS variables
        export SERVER=$( echo "$SERVERS $CLIENTS" | awk '{ print $1 }')
        export CLIENT=$( echo "$SERVERS $CLIENTS" | awk '{ print $2 }')
    fi

    [ -z "$MY_IP" ] && MY_IP=$( hostname -I | awk '{ print $1 }' )
    [ -n "$SERVER" ] && export SERVER_IP=$( get_IP $SERVER )
    [ -n "$CLIENT" ] && export CLIENT_IP=$( get_IP $CLIENT )
}

CRASHKERNLE_REBOOT=/var/tmp/configure-kernel-crashkernel-reboot
SYSRQ_REBOOT=/var/tmp/configure-kernel-SYSRQ-reboot

rlJournalStart

  if [ ! -e $CRASHKERNLE_REBOOT ]; then
    rlPhaseStartSetup
        rlRun "touch $CRASHKERNLE_REBOOT"
        assign_server_roles
        rlLog "SERVER: $SERVER ${SERVER_IP}"
        rlLog "CLIENT: ${CLIENT} ${CLIENT}"
	    rlLog "This system is: $(hostname) ${MY_IP}"
	    rlRun "echo nfs $SERVER:/var/tmp/nfsshare >> /etc/kdump.conf"
        rlRun "sync"
        rlRun "rhts-reboot"
    rlPhaseEnd

  elif [ ! -e $SYSRQ_REBOOT ]; then
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
        rlRun "rm -f $SYSRQ_REBOOT $CRASHKERNLE_REBOOT"
    rlPhaseEnd
  fi
rlJournalEnd
