#!/usr/bin/env sh
# SPDX-License-Identifier: MIT
#
# Copyright (c) 2024 Sohum Mendon

# Script inspired from:
#   - https://wiki.archlinux.org/title/NetworkManager
#   - https://github.com/89luca89/distrobox

# This script should be invoked by NetworkManager's dispatcher.
# See manpage for: NetworkManager-dispatcher(8)
#
# You should install this script to both of the following (default) locations:
#
# /etc/NetworkManager/dispatcher.d/
# /etc/NetworkManager/dispatcher.d/pre-up.d

# This script does not implement a true VPN kill-switch. It implements
# a routing-based VPN kill-switch under the following assumptions:
# 
# 1. There are no IPv4 routes which do not pass through your VPN.
# 2. Processes are unable to use non-OS IPv4 routes.
# 3. IPv6 can be reliably disabled at run-time.
# 4. The system DNS servers are location agnostic.

# As an alternative to this script, you can implement firewall rules
# in your firewall front-end of choice (nft, iptables, ufw, firewall-cmd, ...)
# 
# For OpenVPN, a routing-based solution could try configuring manual IPv6 routes:
#
#   2000::/3 via 0100::1
#
# This is essentially:
#
#   For all public IPv6 adddresses (2000::/3), route to black hole address (any in 0100::/64).
#
# But, it is not that reliable. I would recommend using a firewall-based solution.
# For example, a simple ping can bind to the wrong interface and leak your IPv6 address:
# 
# ping -6 -c 3 -I eth0 google.com

# On a system using journalctl, you can review the logs for the
# NetworkManager-dispatcher.service unit:
# 
# journalctl --follow --unit=NetworkManager-dispatcher.service
#
# The output of this script appears in the logs.

# File structure:
# 
# - program variables
# - helper functions
# - basic argument validation
# - more variables
# - argument validation
# - logic

# POSIX
if command -v basename 2>/dev/null ; then
    prog_name="$(basename "${0:-"vpn-ipv6.sh"}")"
else
    prog_name="${0}"
fi
version="0.1.0"

# Set this variable for more debugging output.
verbose=0

# Print a program-prefixed message to stderr.
# 
#   loge stands for "log error".
# 
# Arguments:
#   string to print (otherwise: the empty string)
# Outputs:
#   prefixed message to stderr
loge() {
    printf >&2 "%s: [E] %s\n" "${prog_name}" "${1:-""}"
}

# Print a program-prefixed message to stdout.
#
#   logi stands for "log info".
#
# Arguments:
#  string to print (otherwise: the empty string)
# Outputs:
#  prefixed message to stdout
logi() {
    printf     "%s: [I] %s\n" "${prog_name}" "${1:-""}"
}

# Disables network entirely, to prevent IP leaks.
#
#   Currently only supports firewalld, which has
#   a built-in panic mode command.
#
#   Requires firewall-cmd   
#
# Arguments:
#   none
# Variables:
#   prog_name
# Outputs:
#   a message to stderr indicating panic mode is set
panic() {
    if firewall-cmd 2>/dev/null --panic-on ; then
        loge "Enabled panic mode"
    else
        loge "Failed to enable panic mode"
    fi
}

# The following code may potentially follow
# a symlink and overwrite an unintentional file.
# However, we assume that:
#   /proc/**
# requires administrative permissions to modify.
# 
# If this is not true, then use a different mechanism
# to disable IPv6.

# Disable IPv6 system-wide.
#
# Arguments:
#   None
# Variables:
#   ipv6ctl = disable_ipv6 file
# Outputs:
#   0 on success
ipv6_down() {
    echo 2>/dev/null 1 > "${ipv6ctl}"
}

# Enables IPv6 system-wide.
#
# Arguments:
#   None
# Variables:
#   ipv6ctl = disable_ipv6 file
# Outputs:
#   0 on success
ipv6_up() {
    echo 2>/dev/null 0 > "${ipv6ctl}"
}

# Print usage to stdout.
# Arguments:
#   None
# Variables:
#   version = version string
#   prog_name = name of program
# Outputs:
#   print usage.
show_help() {
    cat << EOF
(version ${version}) usage: ${prog_name} interface action
EOF
}

if [ "${verbose}" -ne 0 ]; then
    set -o xtrace
fi

if [ $# -ne 2 ]; then
    loge "Expected two args"
    show_help
    exit 1
fi

action_prefix="vpn-"
ipv6ctl="/proc/sys/net/ipv6/conf/all/disable_ipv6"
wg_prefix="wg-"

interface="${1}"
action="${2}"

# This is vulnerable to TOCTOU, but really
# this is just to make sure we're running on
# a compatible operating system.
#
# Who knows if this file will always exist.
# If it doesn't, let's not randomly try to
# make a new file.
if [ ! -w "${ipv6ctl}" ]; then
    loge "file not writable: ${ipv6ctl}"
    exit 1
fi

# There's a bug(?) in NetworkManager 1.44.2-1.fc39
# which treats WireGuard VPNs as the action "up" and "down"
# (no vpn prefix).
#
# OpenVPN doesn't appear to be affected by this.
#
# The heuristic used in my system: WireGuard interfaces
# will start with the "wg-" prefix.
if [ "${interface##"${wg_prefix}"*}x" = "x" ]; then
    action_prefix=""
fi

# We bind to "vpn-pre-up" | "pre-up" to make sure
# that this is killed before the VPN is active.

# If this is a WireGuard interface, we bind to the
# non-prefixed action because of the NetworkManager behavior.
#
# We also unconditionally bind to vpn-* prefixed actions
# in case the NetworkManager behavior is modified in the future.
case "${action}" in
    vpn-pre-up | "${action_prefix}"pre-up)
        logi "Downing ipv6 for ${action} on ${interface}"
        ipv6_down || panic
        ;;
    vpn-down | "${action_prefix}"down)
        logi "Upping ipv6 for ${action} on ${interface}"
        ipv6_up
        ;;
    *)
        [ "${verbose}" -ne 0 ] && logi "Skipping script for ${action} on ${interface}"
        # Set exit 0 explicitly, to avoid terminating 
        # with an error if verbose is not set.
        exit 0
        ;;
esac