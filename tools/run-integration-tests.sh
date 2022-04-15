#!/bin/bash

set -ex

[[ -d ${0%/*} ]] && cd "${0%/*}"/../

VERSION=$(rpmspec -q --queryformat "%{VERSION}" kdump-utils.spec)
SRC_ARCHIVE=kdump-utils-$VERSION.tar.gz
if ! git archive --format=tar.gz -o "$SRC_ARCHIVE" --prefix=kdump-utils-$VERSION/ HEAD; then
	echo "Failed to create kdump-utils source archive"
	exit 1
fi

if ! rpmbuild -ba  --define "_sourcedir $(pwd)" --define "_builddir $(pwd)" --define "_srcrpmdir $(pwd)" --define "_rpmdir $(pwd)" kdump-utils.spec; then
	echo "Failed to build kdump-utils rpm"
	exit 1
fi

arch=$(uname -m)
rpm_name=$(rpmspec -q --queryformat '%{NAME}-%{VERSION}-%{RELEASE}.%{ARCH}' kdump-utils.spec)
rpm_path="$(pwd)/${arch}/${rpm_name}.rpm"
if [[ ! -f $rpm_path ]]; then
	echo "Failed to find built kdump-utils rpm ($path doesn't eixst)"
fi

cd tests && tmt --context custom_mirror=https://mirrors.tuna.tsinghua.edu.cn/fedora run --environment KDUMP_UTILS_RPM="$rpm_path" -a provision -h virtual -c system

