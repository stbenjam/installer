package baremetal

import (
	"github.com/openshift/installer/pkg/ipnet"
	"github.com/openshift/installer/pkg/types/baremetal"
	"github.com/stretchr/testify/assert"
	"testing"
)

func TestTemplatingIPv4(t *testing.T) {
	bareMetalConfig := baremetal.Platform{
		ProvisioningNetworkCIDR:  ipnet.MustParseCIDR("172.22.0.0/24"),
		BootstrapProvisioningIP:  "172.22.0.2",
		ProvisioningDHCPExternal: false,
		ProvisioningDHCPRange:    "172.22.0.10,172.22.0.100",
		Hosts: []*baremetal.Host{
			{
				Role: "master",
				BootMACAddress: "c0:ff:ee:ca:fe:00",
			},
			{
				Role: "master",
				BootMACAddress: "c0:ff:ee:ca:fe:01",
			},
			{
				Role: "master",
				BootMACAddress: "c0:ff:ee:ca:fe:02",
			},
		},
	}

	result := GetTemplateData(&bareMetalConfig)

	assert.Equal(t, result.ProvisioningDHCPRange, "172.22.0.10,172.22.0.100")
	assert.Equal(t, result.ProvisioningStaticLeases, "c0:ff:ee:ca:fe:00,172.22.0.10;c0:ff:ee:ca:fe:01,172.22.0.11;c0:ff:ee:ca:fe:02,172.22.0.12")
	assert.Equal(t, result.ProvisioningCIDR, 24)
	assert.Equal(t, result.ProvisioningIPv6, false)
	assert.Equal(t, result.ProvisioningIP, "172.22.0.2")
}

func TestTemplatingIPv6(t *testing.T) {
	bareMetalConfig := baremetal.Platform{
		ProvisioningNetworkCIDR:  ipnet.MustParseCIDR("fd2e:6f44:5dd8:b856::0/64"),
		BootstrapProvisioningIP:  "fd2e:6f44:5dd8:b856::2",
		ProvisioningDHCPRange:    "fd2e:6f44:5dd8:b856::f,fd2e:6f44:5dd8:b856:ff",
		Hosts: []*baremetal.Host{
			{
				Role: "master",
				BootMACAddress: "c0:ff:ee:ca:fe:00",
			},
			{
				Role: "master",
				BootMACAddress: "c0:ff:ee:ca:fe:01",
			},
			{
				Role: "master",
				BootMACAddress: "c0:ff:ee:ca:fe:02",
			},
		},
	}

	result := GetTemplateData(&bareMetalConfig)

	assert.Equal(t, result.ProvisioningDHCPRange, "fd2e:6f44:5dd8:b856::f,fd2e:6f44:5dd8:b856:ff")
	assert.Equal(t, result.ProvisioningCIDR, 64)
	assert.Equal(t, result.ProvisioningIPv6, true)
	assert.Equal(t, result.ProvisioningIP, "fd2e:6f44:5dd8:b856::2")
	assert.Equal(t, result.ProvisioningStaticLeases, "c0:ff:ee:ca:fe:00,fd2e:6f44:5dd8:b856::f;c0:ff:ee:ca:fe:01,fd2e:6f44:5dd8:b856::10;c0:ff:ee:ca:fe:02,fd2e:6f44:5dd8:b856::11")
}

func TestExternalDHCP(t *testing.T) {
	bareMetalConfig := baremetal.Platform{
		ProvisioningNetworkCIDR:  ipnet.MustParseCIDR("fd2e:6f44:5dd8:b856::0/64"),
		BootstrapProvisioningIP:  "fd2e:6f44:5dd8:b856::2",
		ProvisioningDHCPExternal: true,
	}

	result := GetTemplateData(&bareMetalConfig)

	assert.Equal(t, result.ProvisioningDHCPRange, "")
	assert.Equal(t, result.ProvisioningStaticLeases, "")
	assert.Equal(t, result.ProvisioningCIDR, 64)
	assert.Equal(t, result.ProvisioningIPv6, true)
	assert.Equal(t, result.ProvisioningIP, "fd2e:6f44:5dd8:b856::2")
}


