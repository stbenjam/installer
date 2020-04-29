// +build baremetal

package plugins

import (
	"github.com/hashicorp/terraform-plugin-sdk/plugin"
	"github.com/openshift-metal3/terraform-provider-openshift/openshift"
)

func init() {
	exec := func() {
		plugin.Serve(&plugin.ServeOpts{
			ProviderFunc: openshift.Provider,
		})
	}
	KnownPlugins["terraform-provider-openshift"] = exec
}
