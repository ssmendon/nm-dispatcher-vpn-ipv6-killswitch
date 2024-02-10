#!/usr/bin/env sh
# SPDX-License-Identifier: MIT
# 
# Copyright (c) 2024 Sohum Mendon

# POSIX
prog_name="$(basename "${0:-"install.sh"}")"

# We don't want to execute the script as root.
# Copied from GPL-3.0-only licensed distrobox:
# https://github.com/89luca89/distrobox/blob/e9bf2663dd8af5081657f7e8a51eedbcdbebdef1/distrobox-list#L32-L35
# shellcheck disable=SC2312
if { [ -n "${SUDO_USER}" ] || [ -n "${DOAS_USER}" ]; } && [ "$(id -ru)" -eq 0 ]; then
     printf >&2 "Running %s via SUDO/DOAS is not supported.\n" "${prog_name}"
     exit 1
fi 

set -o errexit
set -o nounset

dispatcher_dir_gen=/etc/NetworkManager/dispatcher.d
dispatcher_dir_preup=/etc/NetworkManager/dispatcher.d/pre-up.d

# Safety: errexit and nounset, and it defaults to a relative path when dirname is empty.
script_path="$(dirname "${0}")"
to_install="${script_path:-.}/10-vpn-ipv6.sh"

sudo_program="sudo"

if [ ! -d "${dispatcher_dir_gen}" ] || [ ! -d "${dispatcher_dir_gen}" ]; then
    printf >&2 "Unable to find one of:\n  %s\n  %s\n" "${dispatcher_dir_gen}" "${dispatcher_dir_preup}"
    exit 1
fi

if [ ! -e "${to_install}" ]; then
    printf >&2 "Unable to find: %s\n" "${to_install}"
    exit 1
fi


if [ -w "${dispatcher_dir_gen}" ] && [ -w "${dispatcher_dir_preup}" ]; then
    sudo_program=""
fi

set -o xtrace

"${sudo_program}" cp "${to_install}" "${dispatcher_dir_gen}"
"${sudo_program}" cp "${to_install}" "${dispatcher_dir_preup}"
