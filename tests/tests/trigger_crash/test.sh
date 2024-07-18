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

rlJournalStart

  if [ $TMT_REBOOT_COUNT == 0 ]; then
    rlPhaseStartSetup
        assign_server_roles
        rlLog "SERVER: $SERVER ${SERVER_IP}"
        rlLog "CLIENT: ${CLIENT} ${CLIENT_IP}"
        rlLog "This system is: $(hostname) ${MY_IP}"
        rlRun "echo nfs ${SERVER}:/var/tmp/nfsshare >> /etc/kdump.conf"
    rlPhaseEnd

    rlPhaseStartTest
        rlRun "kdumpctl restart"
        rlAssertGrep "^1$" /sys/kernel/kexec_crash_loaded
        rlRun "sync"
        rlRun "echo 1 > /proc/sys/kernel/sysrq"
        tmt-reboot -c "echo c > /proc/sysrq-trigger"
    rlPhaseEnd
  fi
rlJournalEnd
