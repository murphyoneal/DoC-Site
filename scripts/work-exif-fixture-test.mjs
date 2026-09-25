// Work-photo EXIF fixture test, against REAL storage (653 (d)). Run locally:
//   node --env-file=.env.local scripts/work-exif-fixture-test.mjs
// Four steps, per the ruling — step 4 is what stops a broken parser passing both files:
//   1. the fixture carries GPS (else the test proves nothing)
//   2. the pipeline's public copy carries none
//   3. the copy SERVED from the public bucket carries none (read back, not assumed)
//   4. the copy in the PRIVATE bucket STILL carries the GPS — and anonymous access to it fails
// Fixture objects are deleted afterwards; they live under _fixture/ and are never referenced.
import sharp from 'sharp'
import { readExifGps } from '../lib/exif-gps.mjs'
import { readOriginal, stripForPublic, metadataFree } from '../lib/work-pipeline.mjs'

const HOST = 'https://eaifqorwmgayiqmbtzcg.supabase.co'
const KEY = process.env.SUPABASE_SECRET_KEY
if (!KEY) { console.error('SUPABASE_SECRET_KEY not set'); process.exit(2) }
const AUTH = { apikey: KEY, Authorization: 'Bearer ' + KEY }
const LAT = 29.2108, LNG = -81.0228   // a Volusia point
let failed = 0
const ok = (cond, msg) => { console.log((cond ? 'PASS ' : 'FAIL ') + msg); if (!cond) failed++ }
const dms = (v) => { v = Math.abs(v); const d = Math.floor(v), mf = (v - d) * 60, m = Math.floor(mf); return `${d}/1 ${m}/1 ${Math.round((mf - m) * 60 * 100)}/100` }

// 1. fixture with GPS
const fixture = await sharp({ create: { width: 640, height: 480, channels: 3, background: { r: 120, g: 150, b: 90 } } })
  .jpeg()
  .withExif({ IFD3: { GPSLatitudeRef: 'N', GPSLatitude: dms(LAT), GPSLongitudeRef: 'W', GPSLongitude: dms(LNG) } })
  .toBuffer()
const orig = await readOriginal(fixture)
ok(orig.gps && Math.abs(orig.gps.lat - LAT) < 1e-4 && Math.abs(orig.gps.lng - LNG) < 1e-4, `1 fixture carries GPS ${JSON.stringify(orig.gps)}`)

// CONTROL: the checker must see metadata in the unstripped original, or steps 2-3 prove nothing.
const ctl = await metadataFree(fixture)
ok(!ctl.free && ctl.found.includes('gps'), `control: checker detects metadata in the original (found: ${ctl.found.join(',')})`)

// 2. pipeline output
const pub = await stripForPublic(fixture)
const pubCheck = await metadataFree(pub.data)
ok(pubCheck.free, `2 pipeline public copy is metadata-free (found: ${pubCheck.found.join(',') || 'none'})`)

// 3. served public copy
const tag = Date.now()
const pubPath = `_fixture/${tag}.jpg`, privPath = `_fixture/${tag}-original.jpg`
const up = async (bucket, path, body, type) => (await fetch(`${HOST}/storage/v1/object/${bucket}/${path}`, { method: 'POST', headers: { ...AUTH, 'Content-Type': type, 'x-upsert': 'false' }, body })).status
ok((await up('work-public', pubPath, pub.data, 'image/jpeg')) === 200, '3a public upload')
const served = Buffer.from(await (await fetch(`${HOST}/storage/v1/object/public/work-public/${pubPath}`)).arrayBuffer())
const servedCheck = await metadataFree(served)
ok(servedCheck.free && readExifGps((await sharp(served).metadata()).exif) === null, `3b SERVED public copy is metadata-free (found: ${servedCheck.found.join(',') || 'none'})`)

// 4. private copy keeps GPS; anonymous access to it fails
ok((await up('work-private', privPath, fixture, 'image/jpeg')) === 200, '4a private upload')
const privRes = await fetch(`${HOST}/storage/v1/object/authenticated/work-private/${privPath}`, { headers: AUTH })
const priv = Buffer.from(await privRes.arrayBuffer())
const privGps = privRes.ok ? readExifGps((await sharp(priv).metadata()).exif) : null
ok(privGps && Math.abs(privGps.lat - LAT) < 1e-4, `4b PRIVATE copy still carries GPS ${JSON.stringify(privGps)}`)
const anon = await fetch(`${HOST}/storage/v1/object/public/work-private/${privPath}`)
ok(!anon.ok, `4c anonymous fetch of the private object is refused (HTTP ${anon.status})`)

// cleanup: fixture objects only
for (const [bucket, path] of [['work-public', pubPath], ['work-private', privPath]]) {
  await fetch(`${HOST}/storage/v1/object/${bucket}`, { method: 'DELETE', headers: { ...AUTH, 'Content-Type': 'application/json' }, body: JSON.stringify({ prefixes: [path] }) })
}
console.log(failed ? `${failed} FAILED` : 'ALL PASSED')
process.exit(failed ? 1 : 0)
