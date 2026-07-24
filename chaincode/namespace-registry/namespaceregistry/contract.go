package namespaceregistry

import (
    "encoding/json"
    "fmt"
    "time"

    "github.com/hyperledger/fabric-contract-api-go/contractapi"
)

// NamespaceContract implements the Hyperledger Fabric smart contract
// for the RecordWeb Protocol namespace registry.
type NamespaceContract struct {
    contractapi.Contract
}

// ─── RegisterNamespace ────────────────────────────────────────────────────────

// RegisterNamespace stores a new namespace entry on the ledger.
// Returns an error if the namespace already exists.
func (c *NamespaceContract) RegisterNamespace(
    ctx contractapi.TransactionContextInterface,
    namespace string,
    resolverEndpoint string,
    registeredBy string,
    endorsedByJSON string, // JSON array, e.g. ["CH","RecordWeb.org"]
) error {
    existing, err := ctx.GetStub().GetState(namespace)
    if err != nil {
        return fmt.Errorf("failed to read state: %w", err)
    }
    if existing != nil {
        return fmt.Errorf("namespace %q already exists", namespace)
    }

    var endorsedBy []string
    if err := json.Unmarshal([]byte(endorsedByJSON), &endorsedBy); err != nil {
        return fmt.Errorf("invalid endorsedBy JSON: %w", err)
    }

    record := NamespaceRecord{
        Namespace:        namespace,
        ResolverEndpoint: resolverEndpoint,
        RegisteredBy:     registeredBy,
        RegisteredAt:     time.Now().UTC().Format(time.RFC3339),
        TxID:             ctx.GetStub().GetTxID(),
        EndorsedBy:       endorsedBy,
    }

    data, err := json.Marshal(record)
    if err != nil {
        return fmt.Errorf("failed to marshal record: %w", err)
    }
    return ctx.GetStub().PutState(namespace, data)
}

// ─── ResolveNamespace ─────────────────────────────────────────────────────────

// ResolveNamespace returns the full NamespaceRecord for the given namespace.
func (c *NamespaceContract) ResolveNamespace(
    ctx contractapi.TransactionContextInterface,
    namespace string,
) (*NamespaceRecord, error) {
    data, err := ctx.GetStub().GetState(namespace)
    if err != nil {
        return nil, fmt.Errorf("failed to read state: %w", err)
    }
    if data == nil {
        return nil, fmt.Errorf("namespace %q not found", namespace)
    }

    var record NamespaceRecord
    if err := json.Unmarshal(data, &record); err != nil {
        return nil, fmt.Errorf("failed to unmarshal record: %w", err)
    }
    return &record, nil
}

// ─── UpdateResolverEndpoint ───────────────────────────────────────────────────

// UpdateResolverEndpoint updates the resolverEndpoint of an existing namespace.
// callerMSP is passed explicitly; in production replace with
// ctx.GetClientIdentity().GetMSPID() (see Track B docs).
func (c *NamespaceContract) UpdateResolverEndpoint(
    ctx contractapi.TransactionContextInterface,
    namespace string,
    newEndpoint string,
    callerMSP string,
) error {
    record, err := c.ResolveNamespace(ctx, namespace)
    if err != nil {
        return err
    }
    if record.RegisteredBy != callerMSP {
        return fmt.Errorf("caller %q is not the registrar of namespace %q", callerMSP, namespace)
    }

    record.ResolverEndpoint = newEndpoint
    record.TxID = ctx.GetStub().GetTxID()

    data, err := json.Marshal(record)
    if err != nil {
        return fmt.Errorf("failed to marshal updated record: %w", err)
    }
    return ctx.GetStub().PutState(namespace, data)
}

// ─── GetNamespaceHistory ──────────────────────────────────────────────────────

// HistoryEntry wraps a single history record with its transaction metadata.
type HistoryEntry struct {
    TxID      string           `json:"txId"`
    Timestamp string           `json:"timestamp"`
    IsDelete  bool             `json:"isDelete"`
    Record    *NamespaceRecord `json:"record,omitempty"`
}

// GetNamespaceHistory returns the full modification history of a namespace.
func (c *NamespaceContract) GetNamespaceHistory(
    ctx contractapi.TransactionContextInterface,
    namespace string,
) ([]*HistoryEntry, error) {
    iter, err := ctx.GetStub().GetHistoryForKey(namespace)
    if err != nil {
        return nil, fmt.Errorf("failed to get history: %w", err)
    }
    defer iter.Close()

    var history []*HistoryEntry
    for iter.HasNext() {
        mod, err := iter.Next()
        if err != nil {
            return nil, fmt.Errorf("error iterating history: %w", err)
        }
        entry := &HistoryEntry{
            TxID:     mod.TxId,
            IsDelete: mod.IsDelete,
        }
        if mod.Timestamp != nil {
            entry.Timestamp = mod.Timestamp.AsTime().UTC().Format(time.RFC3339)
        }
        if !mod.IsDelete && len(mod.Value) > 0 {
            var rec NamespaceRecord
            if err := json.Unmarshal(mod.Value, &rec); err == nil {
                entry.Record = &rec
            }
        }
        history = append(history, entry)
    }
    return history, nil
}