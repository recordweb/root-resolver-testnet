package namespaceregistry

// NamespaceRecord ist die on-chain Datenstruktur für einen RWP-Namespace.
type NamespaceRecord struct {
    Namespace        string   `json:"namespace"`
    ResolverEndpoint string   `json:"resolverEndpoint"`
    RegisteredBy     string   `json:"registeredBy"`
    RegisteredAt     string   `json:"registeredAt"`
    TxID             string   `json:"txId"`
    EndorsedBy       []string `json:"endorsedBy"`
}