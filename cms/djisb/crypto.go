package plugins

import (
  "io"
  "crypto/aes"
  "crypto/cipher"
  "crypto/rand"
  "crypto/sha256"
  "encoding/base64"
  "djusb_clean/internal/pipeline"
)

type Crypto struct{}

func (Crypto) Name() string { return "crypto" }

// Controller rule:
// - if crypto.enabled exists -> obey
// - else -> set enabled=true and write
// - if enabled and nonce missing -> create nonce and write
func (Crypto) Apply(ctx *pipeline.Context) error {
  cval, ok := ctx.Controller["crypto"].(map[string]any)
  if !ok {
    cval = map[string]any{}
    ctx.Controller["crypto"] = cval
    _ = pipeline.SaveController(ctx.JSONPath, ctx.Controller)
  }

  if _, has := cval["enabled"]; !has {
    cval["enabled"] = true
    _ = pipeline.SaveController(ctx.JSONPath, ctx.Controller)
  }
  enabled, _ := cval["enabled"].(bool)
  if !enabled {
    return nil
  }

  nonceB, hasNonce := cval["nonce_b"].(string)
  if !hasNonce || nonceB == "" {
    nonce := make([]byte, 12)
    _, _ = rand.Read(nonce)
    nonceB = base64.StdEncoding.EncodeToString(nonce)
    cval["nonce_b"] = nonceB
    _ = pipeline.SaveController(ctx.JSONPath, ctx.Controller)
  }
  nonce, _ := base64.StdEncoding.DecodeString(nonceB)

  key := sha256.Sum256([]byte(ctx.FilePass)) // MVP placeholder
  block, err := aes.NewCipher(key[:])
  if err != nil { return err }
  gcm, err := cipher.NewGCM(block)
  if err != nil { return err }

  if ctx.Mode == "backup" {
    ctx.W = NewGCMWriter(ctx.W, gcm, nonce)
    return nil
  }
  ctx.R = io.NopCloser(NewGCMReader(ctx.R, gcm, nonce))
  return nil
}
