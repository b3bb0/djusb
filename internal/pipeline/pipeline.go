package pipeline

import (
  "encoding/json"
  "hash"
  "io"
  "os"
)

type Context struct {
  // UI choice
  Mode string // "backup" | "restore"

  IfPath   string
  OfPath   string
  JSONPath string

  // Controller JSON: keys == plugin names
  Controller map[string]any

  // Seeds ONLY when a JSON key is missing
  Seed map[string]any

  // Active stream endpoints
  R io.ReadCloser
  W io.WriteCloser

  // Shared state (set by plugins)
  Hasher hash.Hash

  // Secrets
  FilePass string

  // Finalizers run once after the pipeline (e.g. integrity verify/set)
  Finalizers []func(*Context) error
}

type Plugin interface {
  Name() string
  Apply(*Context) error
}

func LoadController(path string) (map[string]any, bool, error) {
  b, err := os.ReadFile(path)
  if err != nil {
    if os.IsNotExist(err) {
      return nil, false, nil
    }
    return nil, false, err
  }
  var m map[string]any
  if err := json.Unmarshal(b, &m); err != nil {
    return nil, true, err
  }
  return m, true, nil
}

func SaveController(path string, m map[string]any) error {
  b, err := json.MarshalIndent(m, "", "  ")
  if err != nil {
    return err
  }
  return os.WriteFile(path, b, 0o600)
}
