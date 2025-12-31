package pipeline

import "fmt"

func Run(ctx *Context, order []Plugin) error {
  for _, p := range order {
    if err := p.Apply(ctx); err != nil {
      return fmt.Errorf("step %s: %w", p.Name(), err)
    }
  }
  for _, fin := range ctx.Finalizers {
    if err := fin(ctx); err != nil {
      return err
    }
  }
  return nil
}
