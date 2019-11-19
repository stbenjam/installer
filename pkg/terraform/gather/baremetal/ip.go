// Package baremetal contains utilities that help gather Baremetal specific
// information from terraform state.
package baremetal

import (
	"github.com/openshift/installer/pkg/terraform"
	"github.com/pkg/errors"
	"k8s.io/apimachinery/pkg/apis/meta/v1/unstructured"
	utilerrors "k8s.io/apimachinery/pkg/util/errors"
)

// ControlPlaneIPs returns the ip addresses for control plane hosts.
func ControlPlaneIPs(tfs *terraform.State) ([]string, error) {
	mrs, err := terraform.LookupResource(tfs, "module.masters", "ironic_introspection", "openshift-master-introspection")
	if err != nil {
		return nil, errors.Wrap(err, "failed to lookup masters introspection data")
	}

	var errs []error
	var masters []string
	for idx, inst := range mrs.Instances {
		interfaces, _, err := unstructured.NestedSlice(inst.Attributes, "interfaces")
		if err != nil {
			errs = append(errs, errors.Wrapf(err, "could not get interfaces for master-%d", idx))
		}
		ip, _, err := unstructured.NestedString(interfaces[0].(map[string]interface{}), "ip")
		masters = append(masters, ip)
	}
	return masters, utilerrors.NewAggregate(errs)
}
