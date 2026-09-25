// Read GPS latitude/longitude out of a raw EXIF block (as returned by sharp's metadata().exif).
//
// Dependency-free on purpose: it runs in CI, which does not install packages, and it is the
// piece the location check (and therefore the "confirmed on site" state) rests on. It reads only
// the GPS IFD. Anything malformed returns null — "no location data" — never a guessed position,
// because location_not_available must never be confused with a real coordinate.
//
// Layout: optional "Exif\0\0" header, then TIFF: byte order ("II" little / "MM" big), magic 42,
// offset of IFD0. IFD0 tag 0x8825 points at the GPS IFD. In the GPS IFD:
//   0x0001 GPSLatitudeRef  ASCII  'N' | 'S'
//   0x0002 GPSLatitude     RATIONAL x3 (degrees, minutes, seconds)
//   0x0003 GPSLongitudeRef ASCII  'E' | 'W'
//   0x0004 GPSLongitude    RATIONAL x3

export function readExifGps(buf) {
  if (!buf || buf.length < 8) return null
  let base = 0
  if (buf.length >= 6 && buf.toString('latin1', 0, 6) === 'Exif\u0000\u0000') base = 6
  const order = buf.toString('latin1', base, base + 2)
  const le = order === 'II'
  if (!le && order !== 'MM') return null
  const u16 = (o) => (o + 2 <= buf.length ? (le ? buf.readUInt16LE(o) : buf.readUInt16BE(o)) : null)
  const u32 = (o) => (o + 4 <= buf.length ? (le ? buf.readUInt32LE(o) : buf.readUInt32BE(o)) : null)
  if (u16(base + 2) !== 42) return null

  const ifd0 = u32(base + 4)
  if (ifd0 == null) return null
  const gpsOff = findTag(base + ifd0, 0x8825)
  if (gpsOff == null) return null
  const gpsIfd = base + gpsOff.valueOrOffset

  let latRef = null, lngRef = null, lat = null, lng = null
  const n = u16(gpsIfd)
  if (n == null || n > 200) return null
  for (let i = 0; i < n; i++) {
    const e = gpsIfd + 2 + i * 12
    const tag = u16(e), type = u16(e + 2), count = u32(e + 4)
    if (tag == null || type == null || count == null) return null
    if ((tag === 1 || tag === 3) && type === 2) {
      const ch = buf.toString('latin1', e + 8, e + 9)       // ASCII count <= 4 is stored inline
      if (tag === 1) latRef = ch; else lngRef = ch
    } else if ((tag === 2 || tag === 4) && type === 5 && count === 3) {
      const off = u32(e + 8)
      if (off == null) return null
      const v = dms(base + off)
      if (v == null) return null
      if (tag === 2) lat = v; else lng = v
    }
  }
  if (lat == null || lng == null || !latRef || !lngRef) return null
  if (!'NS'.includes(latRef) || !'EW'.includes(lngRef)) return null
  const out = { lat: latRef === 'S' ? -lat : lat, lng: lngRef === 'W' ? -lng : lng }
  if (!(Math.abs(out.lat) <= 90 && Math.abs(out.lng) <= 180)) return null
  if (out.lat === 0 && out.lng === 0) return null   // a zeroed tag is "no fix", not the Gulf of Guinea
  return out

  function findTag(ifdStart, wanted) {
    const count = u16(ifdStart)
    if (count == null || count > 500) return null
    for (let i = 0; i < count; i++) {
      const e = ifdStart + 2 + i * 12
      if (u16(e) === wanted) {
        const valueOrOffset = u32(e + 8)
        return valueOrOffset == null ? null : { valueOrOffset }
      }
    }
    return null
  }
  function rational(o) {
    const num = u32(o), den = u32(o + 4)
    if (num == null || den == null || den === 0) return null
    return num / den
  }
  function dms(o) {
    const d = rational(o), m = rational(o + 8), s = rational(o + 16)
    if (d == null || m == null || s == null) return null
    return d + m / 60 + s / 3600
  }
}
