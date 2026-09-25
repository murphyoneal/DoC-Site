// CI test for lib/exif-gps.mjs — runs with plain `node`, no packages (CI installs none).
// EXIF blocks are built by hand so the test controls every byte, in both byte orders.
import assert from 'node:assert/strict'
import { readExifGps } from './exif-gps.mjs'

// Build "Exif\0\0" + TIFF with IFD0 -> GPS IFD holding lat/lng as degrees/minutes/seconds.
function buildExif({ le = true, lat, lng, latRef = 'N', lngRef = 'W', withGps = true, header = true }) {
  const parts = []
  const w16 = (b, o, v) => (le ? b.writeUInt16LE(v, o) : b.writeUInt16BE(v, o))
  const w32 = (b, o, v) => (le ? b.writeUInt32LE(v, o) : b.writeUInt32BE(v, o))
  // TIFF offsets are relative to the TIFF start.
  const tiff = Buffer.alloc(200)
  tiff.write(le ? 'II' : 'MM', 0, 'latin1'); w16(tiff, 2, 42); w32(tiff, 4, 8)
  // IFD0 at 8: one entry (GPS pointer) or zero entries.
  if (withGps) {
    w16(tiff, 8, 1)
    w16(tiff, 10, 0x8825); w16(tiff, 12, 4); w32(tiff, 14, 1); w32(tiff, 18, 26)
    w32(tiff, 22, 0)
    // GPS IFD at 26: four entries.
    w16(tiff, 26, 4)
    const ent = (i, tag, type, count, val) => { const e = 28 + i * 12; w16(tiff, e, tag); w16(tiff, e + 2, type); w32(tiff, e + 4, count); val(e + 8) }
    const latOff = 80, lngOff = 104
    ent(0, 1, 2, 2, (o) => tiff.write(latRef + '\u0000', o, 'latin1'))
    ent(1, 2, 5, 3, (o) => w32(tiff, o, latOff))
    ent(2, 3, 2, 2, (o) => tiff.write(lngRef + '\u0000', o, 'latin1'))
    ent(3, 4, 5, 3, (o) => w32(tiff, o, lngOff))
    const writeDms = (off, deg) => {
      const d = Math.floor(deg), mf = (deg - d) * 60, m = Math.floor(mf), s = Math.round((mf - m) * 60 * 10000)
      w32(tiff, off, d); w32(tiff, off + 4, 1); w32(tiff, off + 8, m); w32(tiff, off + 12, 1); w32(tiff, off + 16, s); w32(tiff, off + 20, 10000)
    }
    writeDms(latOff, lat); writeDms(lngOff, lng)
  } else {
    w16(tiff, 8, 0); w32(tiff, 10, 0)
  }
  parts.push(header ? Buffer.from('Exif\u0000\u0000', 'latin1') : Buffer.alloc(0), tiff)
  return Buffer.concat(parts)
}

const near = (a, b) => Math.abs(a - b) < 1e-5
// A Volusia point.
const LAT = 29.2108, LNG = 81.0228

for (const le of [true, false]) {
  const g = readExifGps(buildExif({ le, lat: LAT, lng: LNG }))
  assert.ok(g, `decodes (${le ? 'II' : 'MM'})`)
  assert.ok(near(g.lat, LAT) && near(g.lng, -LNG), `correct point (${le ? 'II' : 'MM'}): ${JSON.stringify(g)}`)
}
assert.ok(readExifGps(buildExif({ lat: LAT, lng: LNG, header: false })), 'bare TIFF without the Exif header decodes')

const sw = readExifGps(buildExif({ lat: 33.9, lng: 151.2, latRef: 'S', lngRef: 'E' }))
assert.ok(sw && sw.lat < 0 && sw.lng > 0, 'S/E references set the signs')

assert.equal(readExifGps(buildExif({ withGps: false })), null, 'no GPS IFD -> null, never a position')
assert.equal(readExifGps(null), null, 'null input -> null')
assert.equal(readExifGps(Buffer.from('not exif at all')), null, 'garbage -> null')
assert.equal(readExifGps(buildExif({ lat: 0, lng: 0, lngRef: 'E' })), null, 'zeroed fix -> null, not 0,0')

// NEGATIVE CONTROL: a corrupted reference letter must not decode. If this ever passes, the
// parser has stopped validating and would publish a guessed position as "confirmed".
assert.equal(readExifGps(buildExif({ lat: LAT, lng: LNG, latRef: 'X' })), null, 'bad ref -> null')

// Truncation anywhere must not throw.
const full = buildExif({ lat: LAT, lng: LNG })
for (let n = 0; n < full.length; n += 7) readExifGps(full.subarray(0, n))

console.log('exif-gps: all assertions passed')
