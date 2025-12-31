package pipeline

import (
	"crypto/sha256"
	"encoding/hex"
	"hash"
)

type hashState struct {
	h hash.Hash
}

func newHash() *hashState {
	return &hashState{h: sha256.New()}
}

func (s *hashState) Write(p []byte) (int, error) { return s.h.Write(p) }
func (s *hashState) SumHex() string              { return hex.EncodeToString(s.h.Sum(nil)) }
