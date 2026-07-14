package main

import (
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"flag"
	"fmt"
	"os"
	"path/filepath"
)

type durableFacts struct {
	AttemptID      string `json:"attempt_id"`
	QuoteID        string `json:"quote_id"`
	ReservationID  string `json:"reservation_id"`
	SnapshotDigest string `json:"snapshot_digest"`
	Phase          string `json:"phase"`
}

type dependency struct {
	name      string
	available bool
}

type advanceResult struct {
	providerCalled bool
	denial         string
}

func evaluatePaidBoundary(dependencies []dependency) advanceResult {
	for _, item := range dependencies {
		if !item.available {
			return advanceResult{denial: "DEPENDENCY_UNAVAILABLE:" + item.name}
		}
	}
	return advanceResult{providerCalled: true}
}

func dependenciesFor(scenario string) ([]dependency, error) {
	dependencies := []dependency{
		{name: "budget", available: true},
		{name: "object_store", available: true},
		{name: "quality_gate", available: true},
		{name: "orchestrator", available: true},
	}
	if scenario == "all_available" {
		return dependencies, nil
	}
	wanted := map[string]string{
		"budget_unavailable":       "budget",
		"object_store_unavailable": "object_store",
		"quality_gate_unavailable": "quality_gate",
		"orchestrator_unavailable": "orchestrator",
	}
	name, ok := wanted[scenario]
	if !ok {
		return nil, fmt.Errorf("unknown scenario %q", scenario)
	}
	for index := range dependencies {
		if dependencies[index].name == name {
			dependencies[index].available = false
		}
	}
	return dependencies, nil
}

func writeJSON(path string, value any) error {
	data, err := json.MarshalIndent(value, "", "  ")
	if err != nil {
		return err
	}
	data = append(data, '\n')
	return os.WriteFile(path, data, 0o644)
}

func main() {
	scenario := flag.String("scenario", "", "fault scenario")
	out := flag.String("out", "", "evidence directory")
	flag.Parse()
	if *scenario == "" || *out == "" {
		panic("scenario and out are required")
	}
	if err := os.MkdirAll(*out, 0o755); err != nil {
		panic(err)
	}

	facts := durableFacts{
		AttemptID:      "base002-fail-closed-001",
		QuoteID:        "quote-base002-001",
		ReservationID:  "reservation-base002-001",
		SnapshotDigest: "sha256:3bcdf1a580bf2f1aabec7c1bbd245d11f1905e6300cec03b0abf2775a9fb07ab",
		Phase:          "RESERVED",
	}
	before := filepath.Join(*out, "facts-before.json")
	after := filepath.Join(*out, "facts-after.json")
	if err := writeJSON(before, facts); err != nil {
		panic(err)
	}

	dependencies, err := dependenciesFor(*scenario)
	if err != nil {
		panic(err)
	}
	result := evaluatePaidBoundary(dependencies)
	paidProgress := 0
	providerStatus := "NOT_CALLED"
	status := "PASS"
	denial := result.denial
	paidEvents := "event_type\tattempt_id\n"
	if result.providerCalled {
		paidProgress = 1
		providerStatus = "CALLED"
		status = "CONTROL_PASS"
		denial = "-"
		paidEvents += "provider.submit\t" + facts.AttemptID + "\n"
	}
	if err := os.WriteFile(filepath.Join(*out, "paid-events.tsv"), []byte(paidEvents), 0o644); err != nil {
		panic(err)
	}
	if err := writeJSON(after, facts); err != nil {
		panic(err)
	}
	factBytes, err := os.ReadFile(before)
	if err != nil {
		panic(err)
	}
	digest := sha256.Sum256(factBytes)
	resultTSV := "scenario\tstatus\tpaid_progress\tprovider_submit\tdenial\tfact_digest\n" +
		fmt.Sprintf("%s\t%s\t%d\t%s\t%s\t%s\n", *scenario, status, paidProgress,
			providerStatus, denial, hex.EncodeToString(digest[:]))
	if err := os.WriteFile(filepath.Join(*out, "result.tsv"), []byte(resultTSV), 0o644); err != nil {
		panic(err)
	}
	if err := os.WriteFile(filepath.Join(*out, "audit.log"),
		[]byte(fmt.Sprintf("attempt=%s scenario=%s decision=%s provider=%s\n",
			facts.AttemptID, *scenario, denial, providerStatus)), 0o644); err != nil {
		panic(err)
	}
}
