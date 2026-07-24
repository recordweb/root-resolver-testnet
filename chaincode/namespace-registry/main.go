package main

import (
    "log"

    "github.com/hyperledger/fabric-contract-api-go/contractapi"
    ns "github.com/recordweb/fabric-root-resolver/chaincode/namespace-registry/namespaceregistry"
)

func main() {
    cc, err := contractapi.NewChaincode(&ns.NamespaceContract{})
    if err != nil {
        log.Panicf("Error creating namespace-registry chaincode: %v", err)
    }
    if err := cc.Start(); err != nil {
        log.Panicf("Error starting namespace-registry chaincode: %v", err)
    }
}