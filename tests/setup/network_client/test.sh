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

  rlPhaseStartSetup
      assign_server_roles
      rlLog "SERVER: $SERVER ${SERVER_IP}"
      rlLog "CLIENT: ${CLIENT} ${CLIENT}"
      rlLog "This system is: $(hostname) ${MY_IP}"
  rlPhaseEnd

  rlPhaseStartTest
  if [[ $REMOTE_TYPE == NFS ]]; then
      rlRun "echo nfs $SERVER:/var/tmp/nfsshare >> /etc/kdump.conf"
  elif [[ $REMOTE_TYPE == NFS_EARLY ]]; then
      if [ $TMT_REBOOT_COUNT == 0 ]; then
         rlRun "echo nfs $SERVER:/var/tmp/nfsshare > /etc/kdump.conf"
         rlRun "echo core_collector makedumpfile -l --message-level 7 -d 31 >> /etc/kdump.conf"
         rlRun "kdumpctl start" || rlDie "Failed to start kdump"
         earlykdump_path="/usr/lib/dracut/modules.d/99earlykdump/early-kdump.sh"
         tmp_file="/tmp/.tmp-file"
         cat << EOF > $tmp_file
echo 1 > /proc/sys/kernel/sysrq
echo c > /proc/sysrq-trigger
EOF
         sed -i "/early_kdump_load$/r $tmp_file" $earlykdump_path
         rlRun "cp /boot/initramfs-$(uname -r).img /boot/initramfs-$(uname -r).img.bak"
         rlRun "dracut -f --add earlykdump"
         rlRun "mv /boot/initramfs-$(uname -r).img /boot/initramfs-$(uname -r).img.new"
         rlRun "mv /boot/initramfs-$(uname -r).img.bak /boot/initramfs-$(uname -r).img"
         rlRun "sync"
         rlRun "kexec -s -l /boot/vmlinuz-$(uname -r) --initrd=/boot/initramfs-$(uname -r).img.new --reuse-cmdline  --append=rd.earlykdump"
         tmt-reboot "systemctl kexec"
    fi
  elif [[ $REMOTE_TYPE == SSH ]]; then
    TMT_TEST_PLAN_ROOT=${TMT_PLAN_DATA%data}
    SERVER_SSH_KEY=${TMT_TEST_PLAN_ROOT}/provision/server/id_ecdsa
    if test -f $SERVER_SSH_KEY; then
      rlRun "ssh-keyscan -H $SERVER > /root/.ssh/known_hosts"
      rlRun "ssh root@$SERVER -i $SERVER_SSH_KEY 'mkdir /var/crash'"
      rlRun "echo ssh root@$SERVER > /etc/kdump.conf"
      rlRun "echo sshkey $SERVER_SSH_KEY >> /etc/kdump.conf"
      rlRun "echo core_collector makedumpfile -l --message-level 7 -d 31 -F >> /etc/kdump.conf"
    else
      rlDie "Server SSH Key not found, something wrong"
    fi
  fi
  rlPhaseEnd
rlJournalEnd
