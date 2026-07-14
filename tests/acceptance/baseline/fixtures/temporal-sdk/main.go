package main

import (
	"context"
	"fmt"
	"os"
	"time"

	"go.temporal.io/sdk/activity"
	"go.temporal.io/sdk/client"
	"go.temporal.io/sdk/temporal"
	"go.temporal.io/sdk/worker"
	"go.temporal.io/sdk/workflow"
)

func baselineWorkflow(workflow.Context) (string, error) {
	return "BASE-002 SDK PASS", nil
}

func interruptibleActivity(ctx context.Context) (string, error) {
	if marker := os.Getenv("ACTIVITY_MARKER"); marker != "" {
		if err := os.WriteFile(marker, []byte("started\n"), 0o644); err != nil {
			return "", err
		}
	}
	if os.Getenv("ACTIVITY_HOLD") != "1" {
		return "BASE-002 WORKER RECOVERY PASS", nil
	}

	ticker := time.NewTicker(200 * time.Millisecond)
	defer ticker.Stop()
	for {
		select {
		case <-ctx.Done():
			return "", ctx.Err()
		case <-ticker.C:
			activity.RecordHeartbeat(ctx, "worker-alive")
		}
	}
}

func interruptibleWorkflow(ctx workflow.Context) (string, error) {
	ctx = workflow.WithActivityOptions(ctx, workflow.ActivityOptions{
		StartToCloseTimeout: 30 * time.Second,
		HeartbeatTimeout:    2 * time.Second,
		RetryPolicy: &temporal.RetryPolicy{
			InitialInterval:    time.Second,
			BackoffCoefficient: 1,
			MaximumAttempts:    3,
		},
	})
	var result string
	err := workflow.ExecuteActivity(ctx, interruptibleActivity).Get(ctx, &result)
	return result, err
}

func register(w worker.Worker) {
	w.RegisterWorkflow(baselineWorkflow)
	w.RegisterWorkflow(interruptibleWorkflow)
	w.RegisterActivity(interruptibleActivity)
}

func main() {
	workflowID := os.Getenv("WORKFLOW_ID")
	if workflowID == "" {
		workflowID = "base002-sdk-smoke"
	}

	c, err := client.Dial(client.Options{HostPort: os.Getenv("TEMPORAL_ADDRESS"), Namespace: "ai-video-int"})
	if err != nil {
		panic(err)
	}
	defer c.Close()

	mode := os.Getenv("SDK_MODE")
	if mode == "start" {
		run, err := c.ExecuteWorkflow(context.Background(), client.StartWorkflowOptions{
			ID: workflowID, TaskQueue: "base002-sdk",
		}, interruptibleWorkflow)
		if err != nil {
			panic(err)
		}
		fmt.Printf("WORKFLOW_STARTED %s %s\n", run.GetID(), run.GetRunID())
		return
	}
	if mode == "result" {
		var result string
		if err := c.GetWorkflow(context.Background(), workflowID, "").Get(context.Background(), &result); err != nil {
			panic(err)
		}
		if result != "BASE-002 WORKER RECOVERY PASS" {
			panic(fmt.Sprintf("unexpected recovery result: %q", result))
		}
		fmt.Println(result)
		return
	}

	w := worker.New(c, "base002-sdk", worker.Options{})
	register(w)
	if mode == "worker" {
		fmt.Println("WORKER_READY")
		if err := w.Run(worker.InterruptCh()); err != nil {
			panic(err)
		}
		return
	}
	if err := w.Start(); err != nil {
		panic(err)
	}
	defer w.Stop()

	run, err := c.ExecuteWorkflow(context.Background(), client.StartWorkflowOptions{
		ID:        workflowID,
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
