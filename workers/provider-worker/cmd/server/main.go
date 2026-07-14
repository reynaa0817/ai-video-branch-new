package main

import (
	"encoding/json"
	"fmt"
	"os"
)

const (
	serviceName = "provider-worker"
	serviceKind = "execution-worker"
	factOwner   = false
)

type Health struct {
	ServiceName string `json:"service_name"`
	ServiceKind string `json:"service_kind"`
	FactOwner   bool   `json:"fact_owner"`
	Status      string `json:"status"`
}

func main() {
	status := Health{ServiceName: serviceName, ServiceKind: serviceKind, FactOwner: factOwner, Status: "ok"}
	if len(os.Args) > 1 && os.Args[1] == "contract" {
		status.Status = "contract-boundary-ok"
	}
	out, err := json.Marshal(status)
	if err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
	fmt.Println(string(out))
}
