package plugins

import (
  "compress/gzip"
  "djusb_clean/internal/pipeline"
)

type Compress struct{}

func (Compress) Name() string { return "compress" }

// Controller rule:
// - if compress.enabled exists -> obey
// - else -> set from ctx.Seed["compress"].enabled and write
func (Compress) Apply(ctx *pipeline.Context) error {
  cval, ok := ctx.Controller["compress"].(map[string]any)
  if !ok {
    cval = map[string]any{}
    ctx.Controller["compress"] = cval
    _ = pipeline.SaveController(ctx.JSONPath, ctx.Controller)
  }

  if _, has := cval["enabled"]; !has {
    seed, _ := ctx.Seed["compress"].(map[string]any)
    if v, ok := seed["enabled"].(bool); ok {
      cval["enabled"] = v
    } else {
      cval["enabled"] = false
    }
    _ = pipeline.SaveController(ctx.JSONPath, ctx.Controller)
  }

  enabled, _ := cval["enabled"].(bool)
  if !enabled {
    return nil
  }

  if ctx.Mode == "backup" {
    zw, err := gzip.NewWriterLevel(ctx.W, gzip.BestSpeed)
    if err != nil { return err }
    ctx.W = zw
    return nil
  }

  zr, err := gzip.NewReader(ctx.R)
  if err != nil { return err }
  ctx.R = zr
  return nil
}
