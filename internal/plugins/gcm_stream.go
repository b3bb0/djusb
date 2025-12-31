package plugins

import (
  "crypto/cipher"
  "encoding/binary"
  "errors"
  "io"
)

type gcmWriter struct {
  w       io.Writer
  gcm     cipher.AEAD
  base    [12]byte
  counter uint64
}

func NewGCMWriter(w io.Writer, gcm cipher.AEAD, nonce []byte) io.WriteCloser {
  var b [12]byte
  copy(b[:], nonce)
  return &gcmWriter{w: w, gcm: gcm, base: b}
}

func (s *gcmWriter) Write(p []byte) (int, error) {
  nonce := s.nextNonce()
  ct := s.gcm.Seal(nil, nonce, p, nil)

  if len(ct) > int(^uint32(0)) {
    return 0, errors.New("chunk too large")
  }
  var hdr [4]byte
  binary.LittleEndian.PutUint32(hdr[:], uint32(len(ct)))

  if _, err := s.w.Write(hdr[:]); err != nil { return 0, err }
  if _, err := s.w.Write(ct); err != nil { return 0, err }

  s.counter++
  return len(p), nil
}

func (s *gcmWriter) Close() error {
  if closer, ok := s.w.(io.Closer); ok {
    return closer.Close()
  }
  return nil
}

func (s *gcmWriter) nextNonce() []byte {
  var n [12]byte
  copy(n[:], s.base[:])
  binary.LittleEndian.PutUint64(n[4:], s.counter)
  return n[:]
}

type gcmReader struct {
  r       io.ReadCloser
  gcm     cipher.AEAD
  base    [12]byte
  counter uint64
  buf     []byte
}

func NewGCMReader(r io.ReadCloser, gcm cipher.AEAD, nonce []byte) io.ReadCloser {
  var b [12]byte
  copy(b[:], nonce)
  return &gcmReader{r: r, gcm: gcm, base: b}
}

func (s *gcmReader) Read(p []byte) (int, error) {
  if len(s.buf) == 0 {
    var hdr [4]byte
    if _, err := io.ReadFull(s.r, hdr[:]); err != nil { return 0, err }
    clen := binary.LittleEndian.Uint32(hdr[:])
    ct := make([]byte, clen)
    if _, err := io.ReadFull(s.r, ct); err != nil { return 0, err }
    nonce := s.nextNonce()
    pt, err := s.gcm.Open(nil, nonce, ct, nil)
    if err != nil { return 0, err }
    s.buf = pt
    s.counter++
  }
  n := copy(p, s.buf)
  s.buf = s.buf[n:]
  return n, nil
}

func (s *gcmReader) Close() error {
  return s.r.Close()
}

func (s *gcmReader) nextNonce() []byte {
  var n [12]byte
  copy(n[:], s.base[:])
  binary.LittleEndian.PutUint64(n[4:], s.counter)
  return n[:]
}
