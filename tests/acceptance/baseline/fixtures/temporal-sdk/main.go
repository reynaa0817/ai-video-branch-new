package main

import (
	"context"
	"fmt"
	"os"

	"go.temporal.io/sdk/client"
	"go.temporal.io/sdk/worker"
	"go.temporal.io/sdk/workflow"
)

func baselineWorkflow(workflow.Context) (string, error) {
	return "BASE-002 SDK PASS", nil
}

func main() {
	c, err := client.Dial(client.Options{HostPort: os.Getenv("TEMPORAL_ADDRESS"), Namespace: "ai-video-int"})
	if err != nil {
		panic(err)
	}
	defer c.Close()

	w := worker.New(c, "base002-sdk", worker.Options{})
	w.RegisterWorkflow(baselineWorkflow)
	if err := w.Start(); err != nil {
		panic(err)
	}
	defer w.Stop()

	run, err := c.ExecuteWorkflow(context.Background(), client.StartWorkflowOptions{
		ID:        "base002-sdk-smoke",
		TaskQueue: "base002-sdk",
	}, baselineWorkflow)
	if err != nil {
		panic(err)
	}
	var result string
	if err := run.Get(context.Background(), &result); err != nil {
		panic(err)
	}
	if result != "BASE-002 SDK PASS" {
		panic(fmt.Sprintf("unexpected result: %q", result))
	}
	fmt.Println(result)
}
