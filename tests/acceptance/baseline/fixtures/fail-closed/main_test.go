package main

import "testing"

func TestPaidBoundaryFailsClosedForEachDependency(t *testing.T) {
	scenarios := []string{
		"budget_unavailable",
		"object_store_unavailable",
		"quality_gate_unavailable",
		"orchestrator_unavailable",
	}
	for _, scenario := range scenarios {
		t.Run(scenario, func(t *testing.T) {
			dependencies, err := dependenciesFor(scenario)
			if err != nil {
				t.Fatal(err)
			}
			result := evaluatePaidBoundary(dependencies)
			if result.providerCalled {
				t.Fatal("provider must not be called")
			}
			if result.denial == "" {
				t.Fatal("stable denial reason is required")
			}
		})
	}
}

func TestPaidBoundaryControlCallsProvider(t *testing.T) {
	dependencies, err := dependenciesFor("all_available")
	if err != nil {
		t.Fatal(err)
	}
	result := evaluatePaidBoundary(dependencies)
	if !result.providerCalled || result.denial != "" {
		t.Fatalf("unexpected control result: %+v", result)
	}
}
