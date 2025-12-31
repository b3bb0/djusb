package plugins

import (
  "djusb_clean/internal/pipeline"
  "fmt"
  "io"
  "os"
  "os/exec"
  "runtime"
  "strings"
)

type DiskIO struct{}

func (DiskIO) Name() string { return "diskio" }

// Brainless endpoint open + best-effort disk lock/unmount (MVP).
func (DiskIO) Apply(ctx *pipeline.Context) error {
  if ctx.Controller != nil {
    if _, ok := ctx.Controller["diskio"]; !ok {
      ctx.Controller["diskio"] = map[string]any{}
      _ = pipeline.SaveController(ctx.JSONPath, ctx.Controller)
    }
  }

  // best-effort lock/unmount if path looks like disk
  if isDiskPath(ctx.IfPath) {
    if err := lockUnixUnmount(ctx.IfPath); err != nil { return err }
  }
  if isDiskPath(ctx.OfPath) {
    if err := lockUnixUnmount(ctx.OfPath); err != nil { return err }
  }

  r, err := os.Open(ctx.IfPath)
  if err != nil { return err }

  // If writing to a disk, we should not truncate; open RW.
  // For MVP we treat OfPath as a file path. Full disk write support belongs here.
  w, err := os.OpenFile(ctx.OfPath, os.O_CREATE|os.O_TRUNC|os.O_WRONLY, 0o600)
  if err != nil { _ = r.Close(); return err }

  ctx.R = io.NopCloser(r)
  ctx.W = w
  return nil
}

func isDiskPath(p string) bool {
  if runtime.GOOS == "windows" {
    return strings.HasPrefix(strings.ToLower(p), `\\.\physicaldrive`)
  }
  return strings.HasPrefix(p, "/dev/")
}

func lockUnixUnmount(dev string) error {
  if runtime.GOOS == "windows" {
    return nil // full Windows locking belongs here later
  }
  out, _ := exec.Command("mount").Output()
  for _, l := range strings.Split(string(out), "\n") {
    if strings.Contains(l, dev) && strings.Contains(l, " on ") {
      mp := strings.Split(strings.Split(l, " on ")[1], " ")[0]
      if mp == "" { continue }
      if err := exec.Command("umount", mp).Run(); err != nil {
        return fmt.Errorf("umount %s: %w", mp, err)
      }
    }
  }
  return nil
}
