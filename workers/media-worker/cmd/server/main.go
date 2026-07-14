package main

import (
	"encoding/json"
	"errors"
	"fmt"
	"os"
	"os/signal"
	"syscall"
)

const (
	serviceName = "media-worker"
	serviceKind = "execution-worker"
	factOwner   = false
)

type Health struct {
	ServiceName string `json:"service_name"`
	ServiceKind string `json:"service_kind"`
	FactOwner   bool   `json:"fact_owner"`
	Status      string `json:"status"`
}

func validateContract() error {
	if serviceName == "" {
		return errors.New("service name is required")
	}
	validKind := serviceKind == "bff" || serviceKind == "core-fact-service" || serviceKind == "projection" || serviceKind == "execution-worker"
	if !validKind {
		return fmt.Errorf("unsupported service kind %q", serviceKind)
	}
	if factOwner != (serviceKind == "core-fact-service") {
		return errors.New("fact ownership must match service kind")
	}
	return nil
}

func emit(status string) error {
	return json.NewEncoder(os.Stdout).Encode(Health{serviceName, serviceKind, factOwner, status})
}

func main() {
	if err := validateContract(); err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
	mode := "serve"
	if len(os.Args) > 1 {
		mode = os.Args[1]
	}
	switch mode {
	case "health":
		if err := emit("ok"); err != nil {
			fmt.Fprintln(os.Stderr, err)
			os.Exit(1)
		}
	case "contract":
		if err := emit("contract-boundary-ok"); err != nil {
			fmt.Fprintln(os.Stderr, err)
			os.Exit(1)
		}
	case "serve":
		if err := emit("starting"); err != nil {
			fmt.Fprintln(os.Stderr, err)
			os.Exit(1)
		}
		stop := make(chan os.Signal, 1)
		signal.Notify(stop, syscall.SIGINT, syscall.SIGTERM)
		<-stop
		_ = emit("stopped")
	default:
		fmt.Fprintf(os.Stderr, "unknown mode %q\n", mode)
		os.Exit(2)
	}
}
