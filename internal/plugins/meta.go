package plugins

import "djusb_clean/internal/pipeline"

type Meta struct{}

func (Meta) Name() string { return "meta" }

// Loads controller if exists; otherwise creates it (seeded) and writes it.
// Controller keys == plugin names. Plugins only obey/verify or set/write their own key.
func (Meta) Apply(ctx *pipeline.Context) error {
  ctrl, exists, err := pipeline.LoadController(ctx.JSONPath)
  if err != nil {
    return err
  }
  if !exists {
    if ctx.Seed == nil {
      ctx.Seed = map[string]any{}
    }
    ctrl = map[string]any{}
    for _, k := range []string{"diskio","meta","compress","crypto","integrity","copy"} {
      if v, ok := ctx.Seed[k]; ok {
        ctrl[k] = v
      } else {
        ctrl[k] = map[string]any{}
      }
    }
    if err := pipeline.SaveController(ctx.JSONPath, ctrl); err != nil {
      return err
    }
  }
  ctx.Controller = ctrl
  return nil
}
