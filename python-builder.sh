#!/bin/bash

# Author: Matteo Mattei, http://www.matteomattei.com
# 
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program. If not, see <http://www.gnu.org/licenses/>.

# This script compiles any version of Python you need and store it where you want

usage() {
	# Print the usage
	echo "Usage: ${0} [-d <destination>] [-b <branch>] [-v <version>] [-l]"
	echo "###################################################################################################################"
	echo "-d <destination> | Mandatory: where destination is the folder containing the final bundle"
	echo "-b <branch>      | Mandatory: where branch is the name of the directory as reported in http://python.org/ftp/python"
	echo "-v <version>     | Mandatory: where version is the name of the version as reported in http://python.org/ftp/python"
	echo "-l               | Optional: Build links of generated binaries"
	echo "###################################################################################################################"
	echo "Example: ${0} -d /opt -b 3.4.0 -v 3.4.0b2 -l"
	echo ""
	exit 1
}

dependencies() {
	# Check if all build dependecies are satisfied
	local to_install=()
	local dep_list=(
		build-essential
		wget
		libreadline-dev
		libncurses5-dev
		libssl-dev
		tk8.5-dev
		zlib1g-dev
		liblzma-dev
		libsqlite3-dev
		sqlite3
		bzip2
		libbz2-dev
	)
	for package in "${dep_list[@]}"
	do
		if ! dpkg -l "${package}" 2> /dev/null | grep -q "^ii"
		then
			to_install+=("${package}")
		fi
	done
	if [ ${#to_install[@]} -gt 0 ]
	then
		sudo -p "Some dependencies need to be installed, please enter your password: " apt-get update && sudo apt-get -y install "${to_install[@]}"
		return 0
	fi
}

check_signature() {
	# Check signature of the downloaded archive
	signature=${1}
	archive=${2}

	echo -n "Check signature... "
	gpg --verify "${signature}" "${archive}" > /dev/null 2>&1
	if [ ! ${?} -eq 0 ]
	then
		echo -e -n "DONE\n"
		return
	else
		echo -e -n "ERROR\n"
	fi
	# extract gpg key from error message
	key="$(gpg --verify "${signature}" "${archive}" 2>&1 | awk '{print $NF}' | grep -v found)"

	# now check with gpg_key (should be Python release signing key)
	echo -n "Receiving key... "
	gpg --recv-keys "${key}" > /dev/null 2>&1
	if [ ${?} -gt 0 ]; then echo -e -n "ERROR\n"; else echo -e -n "DONE\n"; fi

	echo -n "Verifying archive... "
	gpg --verify "${signature}" "${archive}" > /dev/null 2>&1
	if [ ${?} -gt 0 ]; then echo -e -n "ERROR\n"; else echo -e -n "DONE\n"; fi
}

build_links() {
	# Create needed links
	echo -n "Building links... "
	bin_path="${1}"
	cd "${bin_path}" > /dev/null 2>&1
	local bin_list=(
		easy_install
		idle
		pip
		pydoc
		python
		pyvenv
	)
	for binary in "${bin_list[@]}"
	do
		if [ ! -e "${binary}" ]
		then
			real=$(ls ${binary}* 2> /dev/null | sort | head -n1)
			if [ ! -z "${real}" ]
			then
				sudo ln -s "${real}" "${binary}"
			fi
		fi
	done
	cd - > /dev/null 2>&1
	echo -e -n "DONE\n"
}
##################################################
####################### MAIN #####################

while getopts ":d:b:v:l" opt; do
	case "${opt}" in
		d)
			destination=${OPTARG%*/}
			;;
		b)
			branch="${OPTARG}"
			;;
		v)
			version="${OPTARG}"
			;;
		l)
			links="true"
			;;
		*)
			usage
			;;
	esac
done

# check parameters
if [ ! -d "${destination}" ] || [ -z "${branch}" ] || [ -z "${version}" ]
then
	usage
fi

# correct path for destination
if ! echo "${destination}" | grep -q "^/"
then
	destination="${PWD}/${destination}"
fi

# check if the output directory already exists
if [[ -d "${destination}/python-${version}" ]]; then 
	echo "Destination folder already exists ( ${destination}/python-${version} ), please rename or remove it."
	exit 1
fi

URL="http://python.org/ftp/python"
remote_file="${URL}/${branch}/Python-${version}.tar.xz"
remote_sign="${URL}/${branch}/Python-${version}.tar.xz.asc"

# check if remote file exists
wget --spider ${remote_file} > /dev/null 2>&1
if [ ! ${?} -eq 0 ]
then
	echo "Remote file ${remote_file} does not exist."
	exit 1
fi

# check if remote signature exists
wget --spider ${remote_sign} > /dev/null 2>&1
if [ ! ${?} -eq 0 ]
then
	asc=0
else
	asc=1
fi

# configure variables
archive="${remote_file##*/}"
if [ ${asc} -eq 1 ]
then
	signature="${remote_sign##*/}"
fi
python_folder="${archive%.*.*}"

# install all needed dependencies
if [ "${branch:0:1}" = "3" ]; then
	if grep -Eiq 'precise' /etc/lsb-release 2> /dev/null; then dep="python3.2"
	elif grep -Eiq '(raring|quanta|saucy)' /etc/lsb-release 2> /dev/null; then dep="python3.3"
	else dep="python3"; fi
elif [ "${branch:0:3}" = "2.7" ]; then
	if grep -Eiq 'lucid' /etc/lsb-release 2> /dev/null; then dep="python2.6"
	else dep="python2.7"; fi
fi
sudo -p "Dependencies installation - please provide your password: " apt-get build-dep ${dep}
dependencies

# dir checks
TMP_BUILD_FOLDER="${HOME}/python_build"
[ -d "${TMP_BUILD_FOLDER}" ] && sudo rm -rf "${TMP_BUILD_FOLDER}"
mkdir "${TMP_BUILD_FOLDER}" && cd "${TMP_BUILD_FOLDER}"

# download python archive and signature
echo -n "Downloading python version ${version} from branch ${branch}... "
wget "${remote_file}" -P "${TMP_BUILD_FOLDER}" > /dev/null 2>&1
if [ ${?} -eq 0 ]; then echo -e -n "DONE\n"; fi
if [ ${asc} -eq 1 ]; then
	echo -n "Downloading related python signature... "
	wget "${remote_sign}" -P "${TMP_BUILD_FOLDER}" > /dev/null 2>&1
	if [ ${?} -eq 0 ]; then echo -e -n "DONE\n"; fi
fi

# Check signature
if [ ${asc} -eq 1 ]
then
	check_signature ${signature} ${archive}
fi

# Archive decompression
echo -n "Decompress archive... "
tar xvJf "${archive}" > /dev/null 2>&1
if [ ${?} -eq 0 ]
then
	echo -e -n "DONE.\n"
else
	echo -e -n "ERROR\n"
	exit 1
fi
cd "${python_folder}" || exit 1

# Start actual configure and make
echo -n "Run configure... "
./configure --prefix=${destination}/python-${version} > /dev/null 2>&1
if [ ${?} -eq 0 ]; then echo -e -n "DONE\n"; fi

echo -n "Run make (it could take a while)... "
make > /dev/null 2>&1
if [ ${?} -eq 0 ]; then echo -e -n "DONE\n"; fi

echo -n "Run make install... "
sudo make install > /dev/null 2>&1
ret=${?}
if [ ${ret} -eq 0 ]; then echo -e -n "DONE\n"; else echo -e -n "ERROR\n"; fi

# Create links
if [ "${links}" = "true" ]
then
	build_links "${destination}/python-${version}/bin"
fi

# Remove build folder
sudo rm -rf "${TMP_BUILD_FOLDER}"

exit ${ret}
