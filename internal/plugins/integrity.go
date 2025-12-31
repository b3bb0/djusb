package plugins

import (
  "crypto/sha256"
  "djusb_clean/internal/pipeline"
  "encoding/hex"
  "fmt"
  "io"
)

type Integrity struct{}

func (Integrity) Name() string { return "integrity" }

// Controller rule:
// - if integrity.sha256 exists -> verify at end
// - else -> set at end
func (Integrity) Apply(ctx *pipeline.Context) error {
  ival, ok := ctx.Controller["integrity"].(map[string]any)
  if !ok {
    ival = map[string]any{}
    ctx.Controller["integrity"] = ival
    _ = pipeline.SaveController(ctx.JSONPath, ctx.Controller)
  }

  if ctx.Hasher == nil {
    ctx.Hasher = sha256.New()
  }

  // Always compute hash over ciphertext stream (whatever is passing here)
  if ctx.Mode == "backup" {
    ctx.W = &teeWriteCloser{w: ctx.W, tee: ctx.Hasher}
  } else {
    // tee reader (preserve close)
    ctx.R = &teeReadCloser{r: ctx.R, tee: ctx.Hasher}
  }

  // finalize verify/set once at end
  ctx.Finalizers = append(ctx.Finalizers, func(c *pipeline.Context) error {
    sum := hex.EncodeToString(c.Hasher.Sum(nil))

    ival2, _ := c.Controller["integrity"].(map[string]any)
    if existing, ok := ival2["sha256"].(string); ok && existing != "" {
      if existing != sum {
        return fmt.Errorf("integrity sha256 mismatch")
      }
      return nil
    }
    ival2["sha256"] = sum
    return pipeline.SaveController(c.JSONPath, c.Controller)
  })

  return nil
}

type teeWriteCloser struct {
  w   io.WriteCloser
  tee io.Writer
}

func (t *teeWriteCloser) Write(p []byte) (int, error) {
  if _, err := t.tee.Write(p); err != nil {
    return 0, err
  }
  return t.w.Write(p)
}
func (t *teeWriteCloser) Close() error { return t.w.Close() }

type teeReadCloser struct {
  r   io.ReadCloser
  tee io.Writer
}

func (t *teeReadCloser) Read(p []byte) (int, error) {
  n, err := t.r.Read(p)
  if n > 0 {
    if _, teeErr := t.tee.Write(p[:n]); teeErr != nil {
      return n, teeErr
    }
  }
  return n, err
}
func (t *teeReadCloser) Close() error { return t.r.Close() }
