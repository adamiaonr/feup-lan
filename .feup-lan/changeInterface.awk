# useful script for editing the /etc/network/interfaces file, written by Joe 
# Kuan in 2009, available in 
# http://joekuan.wordpress.com/2009/11/01/awk-scripts-for-reading-and-editing-ubuntu-etcnetworkinterfaces-file-part-22/

# altered it a little bit to include 'dns-nameservers' option support.

function writeStatic(addr, nw, nm, gw, dns) {

    # minor modification: changed white space tabs to '\t' character and erased 
    # final white space in the end of each config line (e.g. see comment on 
    # 'address' config)

    if (length(addr))
        #print "    address ", addr
        print "\taddress", addr
 
    if (length(nw))
        print "\tnetwork", nw
 
    if (length(nm))
        print "\tnetmask", nm
 
    if (length(gw))
        print "\tgateway", gw

    if (length(dns))
        print "\tdns-nameservers", dns
}
 
function usage() {
        print "awk -f changeInterfaces.awk <interfaces file> device=<eth device> \n" \
            "       [address=<ip addr>] [gateway=<ip addr>] [netmask=<ip addr>]\n" \
            "       [network=<ip addr>] [dns=<ip addr 1>:<ip addr 2>:<ip addr 3>]\n" \
            "       [mode=dhcp|static] [arg=debug]"
}
 
BEGIN { start = 0;
 
    if (ARGC < 3 || ARGC > 10) {
        usage();
        exit 1;
    }
 
    for (i = 2; i < ARGC; i++) {
        split(ARGV[i], pair, "=");
        if (pair[1] == "address")
            address = pair[2];
        else if (pair[1] == "gateway")
            gateway = pair[2];
        else if (pair[1] == "network")
            network = pair[2];
        else if (pair[1] == "netmask")
            netmask = pair[2];
        else if (pair[1] == "dns")
            dns = pair[2];
        else if (pair[1] == "device")
            device = pair[2];
        else if (pair[1] == "arg" && pair[2] == "debug")
            debug = 1;
        else if (pair[1] == "mode" && pair[2] == "dhcp")
            dhcp = 1;
        else if (pair[1] == "mode" && pair[2] == "static")
            static = 1;
        else {
            usage();
            exit 1;
        }
    }
 
    # Sort out the logic of argument
    if (dhcp && (length(network) || length(gateway) || length(address) || length(netmask) || length(dns))) {
        print "Both DHCP and static properties are defined";
        usage();
        exit 1;
    }
}
 
{
    # Look for iface line and if the interface comes with the device name
    # scan whether it is dhcp or static
    if ($1 == "iface")  {
 
        # Ethernet name matches - switch the line scanning on
        if ($2 == device) {
 
            if (debug)
                print $0;
 
            # It's a DHCP interface, if defined any static properties
            # change it to static
            if (match($0, / dhcp/)) {
                definedDhcp=1;
                # Change to static if defined properties
                if (length(address) || length (gateway) || length(netmask) || 
                    length (network) || length (dns) || static) {
                    print "iface", device, "inet static";
                    next;
                }
            }
 
            # It's a static network interface
            else if (match ($0, / static/)) {
                definedStatic=1;
                # Change to dhcp if defined
                if (dhcp) {
                    sub(/ static/, " dhcp");
                    print $0;
                    next;
                }
            }
 
        }
        # If it is other inteface line, switch it off
        else {
            definedStatic = 0;
            definedDhcp = 0;
        }
 
        print $0;
        next;
    }
 
    # Reaches here - means non iface lines
    # Change the static content
    if (definedStatic) {
 
        # Already defined static, just changing the properties
        # Otherwise omit everything until the iface section is
        # finished
        if (!dhcp) {
 
            if (debug)
                print "static - ", $0, $1;
 
            if ($1 == "address" && length(address))
                print "\taddress", address
 
            else if ($1 == "netmask" && length(netmask))
                print "\tnetmask", netmask;
 
            else if ($1 == "gateway" && length(gateway))
                print "\tgateway", gateway;
 
            else if ($1 == "network" && length(network))
                print "\tnetwork", network;

            # added small section for dns-namservers
            else if ($1 == "dns-nameservers" && length(dns)) {

                # replace the 'split' characters (':') to white spaces ' '
                gsub(":", " ", dns);
                print "\tdns-nameservers", dns;
            }
            else
                print $0;
        }
        next;
    }
 
    # If already defined dhcp, then dump the network properties
    if (definedDhcp) {
        writeStatic(address, network, netmask, gateway, dns);
        definedDhcp = 0;
        next;
    }
 
    print $0;
}
 
END {
    # This bit is useful at the condition when the last line is
    # iface dhcp
    if (definedDhcp)
        writeStatic(address, network, netmask, gateway, dns);
}
