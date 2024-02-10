# nm-dispatcher-vpn-ipv6-killswitch

An IPv6-disabling script for NetworkManager and WireGuard VPNs.

It disables your system's IPv6 connectivity using the `proc(5)` pseudo-filesystem just before your VPN comes up. It re-enables IPv6 when your VPN comes down.

It's invoked by [NetworkManager-dispatcher][nm-dispatcher].


## Why?

The motivation is succinctly explained by the [Arch Linux wiki](arch-wiki). Plenty of commercial VPNs don't support IPv6, and it's very easy to leak your IPv6 address because of it.

## Usage

Install the [`10-vpn-ipv6.sh`](./10-vpn-ipv6.sh) file inside of:

- `/etc/NetworkManager/dispatcher.d` 
- `/etc/NetworkManager/dispatcher.d/pre-up.d`

and toggle your VPN connection in NetworkManager.

### config

You may need to modify the following variables in the script:

- `wg-prefix` to a prefix which applies to your WireGuard VPN connections.

An [`install.sh`](./install.sh) script is provided for your convenience.

Read the manual on [NetworkManager-dispatcher][nm-dispatcher] for any other requirements (for example, file permissions).

The source code of the script is heavily documented, so give it a read. Especially since I'm not sure that it is portable across all Linux systems.

## Caveats

> [!WARNING]
> A better solution than this would involve writing firewall rules to disable non-VPN traffic, and to ensure that the DNS provider in use is location agnostic (e.g. not your ISP DNS).

You can find resources on other kinds of killswitch set-ups, but here are a few not endorsed sources to give you inspiration:

<details>

- https://discuss.privacyguides.net/t/any-way-to-add-a-vpn-killswitch-to-network-manager/15229/4
- https://discussion.fedoraproject.org/t/how-can-i-configure-a-killswitch-for-openvpn-using-firewalld/76361
- https://discussion.fedoraproject.org/t/wireguard-vpn-via-network-manager-kill-switch/101720
- https://michael.kjorling.se/blog/2022/using-linux-nftables-to-block-traffic-outside-of-a-vpn-tunnel/
- https://gist.github.com/Necklaces/18b68e80bf929ef99312b2d90d0cded2
- https://meow464.neocities.org/blog/firewalld-vpn-killswitch/
- https://unix.stackexchange.com/questions/731004/configuring-a-firewalld-killswitch
- https://mullvad.net/en/help/wireguard-and-mullvad-vpn#killswitch

</details>

### firewalld

This script assumes that you have [firewalld](https://firewalld.org) installed for its panic mode functionality, but it will mostly work even without it.

Panic mode will only be triggered when enabling the VPN if there's a failure writing to the disable bit. Any other errors will terminate without enabling panic mode.

### effectiveness

In order for this script to be effective, your VPN connection should already block non-VPN IPv4 traffic. It doesn't take care of any issues related to DNS either, so hopefully that's set in NetworkManager's connection profile.

I think that NetworkManager 1.20.0 has support for `wireguard.ip4-auto-default-route`, which may help with IPv4 routing leaks. You can read more about NetworkManager WireGuard support in [Thomas Haller's blog](https://blogs.gnome.org/thaller/2019/03/15/wireguard-in-networkmanager/).

## Inspiration

- The [Arch Linux wiki on NetworkManager VPNs][arch-wiki]
- The [distrobox source code][distrobox] for shell script conventions


[arch-wiki]: https://wiki.archlinux.org/title/NetworkManager#Use_dispatcher_to_disable_IPv6_on_VPN_provider_connections
[nm-dispatcher]: https://networkmanager.dev/docs/api/latest/NetworkManager-dispatcher.html
[distrobox]: https://github.com/89luca89/distrobox
