package main

import (
  "flag"
  "fmt"
  "os"

  "djusb_clean/internal/pipeline"
  "djusb_clean/internal/plugins"
)

func main() {
  if len(os.Args) < 2 {
    usage()
    os.Exit(2)
  }
  switch os.Args[1] {
  case "dd":
    cmdDD(os.Args[2:])
  default:
    usage()
    os.Exit(2)
  }
}

func usage() {
  fmt.Fprintln(os.Stderr, "usage: djusb dd --mode=backup|restore --if=... --of=... --json=... --filepass=... [--compress=true|false]")
}

func cmdDD(args []string) {
  fs := flag.NewFlagSet("dd", flag.ExitOnError)
  mode := fs.String("mode", "", "backup|restore (chosen by UI)")
  ifp := fs.String("if", "", "input path (disk/file)")
  ofp := fs.String("of", "", "output path (disk/file)")
  jsonp := fs.String("json", "", "json controller path")
  filepass := fs.String("filepass", "", "file password")
  compressSeed := fs.Bool("compress", false, "seed compress.enabled only if json missing")
  _ = fs.Parse(args)

  if *mode != "backup" && *mode != "restore" {
    fatal("missing/invalid --mode")
  }
  if *ifp == "" || *ofp == "" || *jsonp == "" || *filepass == "" {
    fatal("missing required flags")
  }

  ctx := &pipeline.Context{
    Mode: *mode,
    IfPath: *ifp,
    OfPath: *ofp,
    JSONPath: *jsonp,
    FilePass: *filepass,
    Seed: map[string]any{
      "compress": map[string]any{"enabled": *compressSeed},
    },
  }

  // UI only changes the order:
  var order []pipeline.Plugin
  if *mode == "backup" {
    order = []pipeline.Plugin{
      plugins.DiskIO{},
      plugins.Meta{},
      plugins.Compress{},
      plugins.Crypto{},
      plugins.Integrity{},
      plugins.Copy{},
    }
  } else {
    order = []pipeline.Plugin{
      plugins.DiskIO{},
      plugins.Meta{},
      plugins.Crypto{},
      plugins.Compress{},
      plugins.Integrity{},
      plugins.Copy{},
    }
  }

  if err := pipeline.Run(ctx, order); err != nil {
    fatalErr(err)
  }

  // Forcibly close resources to ensure cleanup
  if ctx.R != nil {
    _ = ctx.R.Close()
  }
  if ctx.W != nil {
    _ = ctx.W.Close()
  }
}

func fatal(msg string) {
  fmt.Fprintln(os.Stderr, "error:", msg)
  os.Exit(1)
}
func fatalErr(err error) {
  fmt.Fprintln(os.Stderr, "error:", err)
  os.Exit(1)
}
