#!/bin/sh -eux

has_valid_vmcore_dir() {
	local path=$1
	local vmcore_dir
	local vmcore="<invalid>"

	MAX_WAIT_TIME=300
	_waited=0
	while [ $_waited -le $MAX_WAIT_TIME ]; do
		if ls -1 $path &> /dev/null; then
			vmcore_dir=$path/$(ls -1 $path | tail -n 1)
			break
		fi
		_waited=$((_waited+1))
	done

	if [[ $_waited -ge $MAX_WAIT_TIME ]]; then
		echo "No Vmcore found!" 1>&2
		return 1
	fi

	echo "Found a vmcore dir \"$vmcore_dir\":"
	# Checking with `crash` is slow and consume a lot of memory/disk,
	# just do a sanity check by check if log are available.
	if [ -e $vmcore_dir/vmcore ]; then
		vmcore=$vmcore_dir/vmcore
		makedumpfile --dump-dmesg $vmcore $vmcore_dir/vmcore-dmesg.txt.2 || {
			echo "Failed to retrive dmesg from vmcore!"
			return 1
		}
	elif [ -e $vmcore_dir/vmcore.flat ]; then
		vmcore=$vmcore_dir/vmcore.flat
		makedumpfile -R $vmcore_dir/vmcore < $vmcore || return 1
		makedumpfile --dump-dmesg $vmcore_dir/vmcore $vmcore_dir/vmcore-dmesg.txt.2 || {
			echo "Failed to retrive dmesg from vmcore!"
			return 1
		}
		rm $vmcore_dir/vmcore
	else
		echo "The vmcore dir is empty!"
		return 1
	fi

	if ! diff -w $vmcore_dir/vmcore-dmesg.txt.2 $vmcore_dir/vmcore-dmesg.txt; then
		echo "Dmesg retrived from vmcore is different from dump version!"
		return 1
	fi

	echo "VMCORE: $vmcore"
	echo "KERNEL VERSION: $(rpm -q kernel-core)"

	return 0
}

has_valid_vmcore_dir "/var/tmp/nfsshare/var/crash/"
