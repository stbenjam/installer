package baremetal

import (
	"github.com/openshift/installer/pkg/types/baremetal"
)

// BareMetalTemplateData holds data specific to templates used for the baremetal platform.
type BareMetalTemplateData struct {
	// ProvisioningIP holds the IP the bootstrap node will use to service Ironic, TFTP, etc.
	ProvisioningIP string

	// ProvisioningIPv6 determines if we are using IPv6 or not.
	ProvisioningIPv6 bool

	// ProvisioningCIDR has the integer CIDR notation, e.g. 255.255.255.0 should be "24"
	ProvisioningCIDR int

	// ProvisioningDHCPRange has the DHCP range, if DHCP is not external. Otherwise it
	// should be blank.
	ProvisioningDHCPRange string
}

// TemplateData returns platform-specific data for bootstrap templates.
func TemplateData(config *baremetal.Platform) *BareMetalTemplateData {
	var bareMetalTemplateData BareMetalTemplateData

	bareMetalTemplateData.ProvisioningIP = config.BootstrapProvisioningIP
	bareMetalTemplateData.ProvisioningCIDR = config.ProvisioningNetworkCIDR.CIDR()
	bareMetalTemplateData.ProvisioningIPv6 = config.ProvisioningNetworkCIDR.Version() == 6

	if !config.ProvisioningDHCPExternal {
		bareMetalTemplateData.ProvisioningDHCPRange = config.ProvisioningDHCPRange
	}

	return &bareMetalTemplateData
}
