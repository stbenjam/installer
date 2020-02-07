package baremetal

import (
	"fmt"
	"github.com/apparentlymart/go-cidr/cidr"
	"github.com/openshift/installer/pkg/types/baremetal"
	"net"
	"strings"
)

// TemplateData holds data specific to templates used for the baremetal platform.
type TemplateData struct {
	// ProvisioningIP holds the IP the bootstrap node will use to service Ironic, TFTP, etc.
	ProvisioningIP string

	// ProvisioningIPv6 determines if we are using IPv6 or not.
	ProvisioningIPv6 bool

	// ProvisioningCIDR has the integer CIDR notation, e.g. 255.255.255.0 should be "24"
	ProvisioningCIDR int

	// ProvisioningDHCPRange has the DHCP range, if DHCP is not external. Otherwise it
	// should be blank.
	ProvisioningDHCPRange string

	// ProvisioningStaticLeases contains a list of static DHCP leases that the bootstrap
	// DHCP server should respond to. The format is: <MAC>,<IP>[;<MAC>,<IP>...]. For example:
	// 		C0:FF:EE:CA:FE:00,172.22.0.10;C0:FF:EE:CA:FE:01,172.22.0.11
	ProvisioningStaticLeases string
}

// GetTemplateData returns platform-specific data for bootstrap templates.
func GetTemplateData(config *baremetal.Platform) *TemplateData {
	var templateData TemplateData

	templateData.ProvisioningIP = config.BootstrapProvisioningIP

	provisioningCIDR, _ := config.ProvisioningNetworkCIDR.Mask.Size()
	templateData.ProvisioningCIDR = provisioningCIDR

	templateData.ProvisioningIPv6 = config.ProvisioningNetworkCIDR.IP.To4() == nil

	if !config.ProvisioningDHCPExternal {
		templateData.ProvisioningDHCPRange = config.ProvisioningDHCPRange

		var dhcpStaticLeases []string
		leaseGenerator := leaseGenerator(config)
		for _, host := range config.Hosts {
			if host.Role == "master" {
				dhcpStaticLeases = append(dhcpStaticLeases, fmt.Sprintf("%s,%s", host.BootMACAddress, leaseGenerator()))
			}
		}
		templateData.ProvisioningStaticLeases = strings.Join(dhcpStaticLeases, ";")
	}

	return &templateData
}

// leaseGenerator is a helper function that returns the next available IP from the
// DHCP range.
func leaseGenerator(config *baremetal.Platform) func() string {
	// The provisioning DHCP range will be some offset into the network CIDR. We need to
	// parse the DHCP range, and get the last byte to figure out where our first lease is.
	leaseIP := net.ParseIP(strings.Split(config.ProvisioningDHCPRange, ",")[0])
	leaseOffset := int(leaseIP[len(leaseIP) - 1])

	// Return a function that returns the next IP address on each subsequent call
	return func() string {
		ip, _ := cidr.Host(&config.ProvisioningNetworkCIDR.IPNet, leaseOffset)
		leaseOffset++
		return ip.String()
	}
}
