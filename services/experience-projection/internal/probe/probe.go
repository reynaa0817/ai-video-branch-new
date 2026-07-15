package probe

import (
	"bytes"
	"context"
	"crypto/sha256"
	"encoding/base64"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"os"
	"strings"
	"time"

	"github.com/IBM/sarama"
	"github.com/aif-go/ag-core/ag/ag_log"
	"github.com/aif-go/ag-core/contribute/agdb"
	"github.com/aif-go/ag-core/contribute/agdb/gormdb"
	"github.com/aif-go/ag-core/contribute/agsarama"
	"github.com/aif-go/ag-core/fxs"
	"github.com/frochyzhang/ai-video/services/experience-projection/internal/repository/dao"
	"github.com/frochyzhang/ai-video/services/experience-projection/internal/repository/model"
	"go.uber.org/fx"
)

const (
	topic             = "ai-video-story13-events"
	groupID           = "story13-experience-projection"
	envelopeSchema    = "ai.video.platform.v1.DomainEventEnvelope"
	expectedOwner     = "studio"
	expectedEventKind = "ProjectCreationSkeleton"
)

type Envelope struct {
	EventID          string `json:"event_id"`
	WorkspaceID      string `json:"workspace_id"`
	AggregateID      string `json:"aggregate_id"`
	AggregateVersion int64  `json:"aggregate_version"`
	OwnerDomain      string `json:"owner_domain"`
	EventKind        string `json:"event_kind"`
	SchemaVersion    string `json:"schema_version"`
	OccurredAt       string `json:"occurred_at"`
	Producer         string `json:"producer"`
	Trace            struct {
		TraceID   string `json:"trace_id"`
		SpanID    string `json:"span_id"`
		RequestID string `json:"request_id"`
	} `json:"trace"`
	Payload string `json:"payload"`
}

type runner struct {
	dao   dao.IStory13ProjectionDao
	kafka sarama.Client
}

func newRunner(projection dao.IStory13ProjectionDao, kafka sarama.Client) *runner {
	return &runner{dao: projection, kafka: kafka}
}

func newKafkaClient(lifecycle fx.Lifecycle) (sarama.Client, error) {
	cfg := agsarama.NewDefaultConfig()
	cfg.Brokers = splitList(envDefault("KAFKA_BROKERS", "kafka:29092"))
	cfg.Consumer.Offsets.Initial = sarama.OffsetOldest
	cfg.Consumer.Offsets.AutoCommit.Enable = true
	client, err := agsarama.NewClientWithAgConfig(cfg)
	if err != nil {
		return nil, err
	}
	lifecycle.Append(fx.Hook{OnStop: func(context.Context) error { return client.Close() }})
	return client, nil
}

func Run(ctx context.Context, mode string) error {
	r, stop, err := startDB(ctx)
	if err != nil {
		return err
	}
	defer stop()
	switch mode {
	case "inspect-projection":
		return r.inspect(ctx)
	default:
		return fmt.Errorf("unknown probe mode %q", mode)
	}
}

func Serve(ctx context.Context) error {
	r, stop, err := startConsumer(ctx)
	if err != nil {
		return err
	}
	defer stop()
	return r.consumeLoop(ctx)
}

func CheckDatabase(ctx context.Context) error {
	r, stop, err := startDB(ctx)
	if err != nil {
		return err
	}
	defer stop()
	_, err = r.dao.FindByPrimaryKey(ctx, model.Story13ProjectionPrimaryKey("__story13_readiness_probe__"))
	return err
}

func startDB(ctx context.Context) (*runner, func(), error) {
	var r *runner
	app := fx.New(
		fxs.FxAgConfModule,
		ag_log.FxAglogMode,
		gormdb.FxAicGromdbModule,
		agdb.FxAgDbModule,
		fx.Provide(dao.NewStory13ProjectionDao, func(projection dao.IStory13ProjectionDao) *runner {
			return &runner{dao: projection}
		}),
		fx.Populate(&r),
	)
	if err := app.Start(ctx); err != nil {
		return nil, nil, err
	}
	return r, func() { _ = app.Stop(context.Background()) }, nil
}

func startConsumer(ctx context.Context) (*runner, func(), error) {
	var r *runner
	app := fx.New(
		fxs.FxAgConfModule,
		ag_log.FxAglogMode,
		gormdb.FxAicGromdbModule,
		agdb.FxAgDbModule,
		fx.Provide(newKafkaClient, dao.NewStory13ProjectionDao, newRunner),
		fx.Populate(&r),
	)
	if err := app.Start(ctx); err != nil {
		return nil, nil, err
	}
	return r, func() { _ = app.Stop(context.Background()) }, nil
}

func (r *runner) consumeLoop(ctx context.Context) error {
	group, err := sarama.NewConsumerGroupFromClient(groupID, r.kafka)
	if err != nil {
		return fmt.Errorf("create consumer group: %w", err)
	}
	defer group.Close()
	handler := &handler{runner: r}
	for ctx.Err() == nil {
		if err := group.Consume(ctx, []string{topic}, handler); err != nil {
			fmt.Fprintf(os.Stderr, "story13 projection consume failed: %v\n", err)
			time.Sleep(time.Second)
		}
	}
	return nil
}

type handler struct {
	runner *runner
}

func (h *handler) Setup(sarama.ConsumerGroupSession) error   { return nil }
func (h *handler) Cleanup(sarama.ConsumerGroupSession) error { return nil }
func (h *handler) ConsumeClaim(session sarama.ConsumerGroupSession, claim sarama.ConsumerGroupClaim) error {
	for {
		select {
		case <-session.Context().Done():
			return nil
		case msg, ok := <-claim.Messages():
			if !ok {
				return nil
			}
			if err := h.runner.project(session.Context(), msg); err != nil {
				return err
			}
			session.MarkMessage(msg, "")
		}
	}
}

func (r *runner) project(ctx context.Context, msg *sarama.ConsumerMessage) error {
	event, err := decodeEnvelope(msg.Value)
	if err != nil {
		return fmt.Errorf("reject event at %s/%d/%d: %w", msg.Topic, msg.Partition, msg.Offset, err)
	}
	row := &model.Story13Projection{
		EventId:          event.EventID,
		WorkspaceId:      event.WorkspaceID,
		AggregateId:      event.AggregateID,
		AggregateVersion: event.AggregateVersion,
		ProjectionState:  "projected",
		KafkaPartition:   int(msg.Partition),
		KafkaOffset:      msg.Offset,
		TraceId:          event.Trace.TraceID,
		SpanId:           event.Trace.SpanID,
		RequestId:        event.Trace.RequestID,
		EnvelopeDigest:   digestBytes(msg.Value),
	}
	existing, err := r.dao.FindByPrimaryKey(ctx, model.Story13ProjectionPrimaryKey(event.EventID))
	if err != nil {
		return err
	}
	if existing != nil {
		if existing.EnvelopeDigest != row.EnvelopeDigest || existing.AggregateId != row.AggregateId || existing.WorkspaceId != row.WorkspaceId {
			return fmt.Errorf("projection %s already exists with different identity", event.EventID)
		}
		return nil
	}
	if _, err := r.dao.InsertOne(ctx, row); err != nil {
		return fmt.Errorf("persist projection: %w", err)
	}
	return nil
}

func (r *runner) inspect(ctx context.Context) error {
	eventID := strings.TrimSpace(os.Getenv("PROBE_EVENT_ID"))
	if eventID == "" {
		return errors.New("PROBE_EVENT_ID is required")
	}
	row, err := r.dao.FindByPrimaryKey(ctx, model.Story13ProjectionPrimaryKey(eventID))
	if err != nil {
		return err
	}
	if row == nil {
		return errors.New("projection not found")
	}
	return writeJSON(map[string]any{
		"event_id": row.EventId, "workspace_id": row.WorkspaceId, "aggregate_id": row.AggregateId,
		"aggregate_version": row.AggregateVersion, "projection_state": row.ProjectionState,
		"partition": row.KafkaPartition, "offset": row.KafkaOffset, "trace_id": row.TraceId,
		"span_id": row.SpanId, "request_id": row.RequestId, "envelope_digest": row.EnvelopeDigest,
		"storage": "mysql.STORY13_PROJECTION",
	})
}

func decodeEnvelope(raw []byte) (*Envelope, error) {
	dec := json.NewDecoder(bytes.NewReader(raw))
	dec.DisallowUnknownFields()
	var event Envelope
	if err := dec.Decode(&event); err != nil {
		return nil, fmt.Errorf("decode envelope: %w", err)
	}
	if err := dec.Decode(&struct{}{}); err != io.EOF {
		return nil, errors.New("decode envelope: trailing JSON data")
	}
	if event.EventID == "" || event.WorkspaceID == "" || event.AggregateID == "" || event.AggregateVersion < 1 {
		return nil, errors.New("invalid envelope identity")
	}
	if event.OwnerDomain != expectedOwner || event.Producer != expectedOwner || event.EventKind != expectedEventKind || event.SchemaVersion != envelopeSchema {
		return nil, errors.New("invalid envelope type")
	}
	if _, err := time.Parse(time.RFC3339, event.OccurredAt); err != nil {
		return nil, fmt.Errorf("invalid occurred_at: %w", err)
	}
	if event.Trace.TraceID == "" || event.Trace.SpanID == "" || event.Trace.RequestID == "" {
		return nil, errors.New("trace identity is required")
	}
	if payload, err := base64.StdEncoding.DecodeString(event.Payload); err != nil || len(payload) == 0 {
		return nil, errors.New("payload must be non-empty base64")
	}
	return &event, nil
}

func splitList(value string) []string {
	var result []string
	for _, item := range strings.Split(value, ",") {
		if item = strings.TrimSpace(item); item != "" {
			result = append(result, item)
		}
	}
	return result
}

func envDefault(key, fallback string) string {
	if value := strings.TrimSpace(os.Getenv(key)); value != "" {
		return value
	}
	return fallback
}

func digestBytes(value []byte) string {
	sum := sha256.Sum256(value)
	return hex.EncodeToString(sum[:])
}

func writeJSON(value any) error { return json.NewEncoder(os.Stdout).Encode(value) }
