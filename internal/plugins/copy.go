package plugins

import (
  "djusb_clean/internal/pipeline"
  "io"
)

type Copy struct{}

func (Copy) Name() string { return "copy" }

// Brainless copy; chunk size fixed at 8MiB in caller (MVP uses io.CopyBuffer).
func (Copy) Apply(ctx *pipeline.Context) error {
  buf := make([]byte, 8*1024*1024)
  _, err := io.CopyBuffer(ctx.W, ctx.R, buf)
  // close endpoints (flush gzip, etc.)
  _ = ctx.W.Close()
  _ = ctx.R.Close()
  return err
}
