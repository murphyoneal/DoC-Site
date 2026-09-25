// The work-photo pipeline core (653 (d); rulings 611, 613). Shared by the upload route and the
// fixture test so the test exercises the code that ships, not a copy of it.
//
// ORDER IS LOAD-BEARING: read GPS from the ORIGINAL first (the location check needs it), then
// re-encode. Re-encoding — not a "remove metadata" flag — is what strips: sharp writes a fresh
// JPEG and copies no EXIF, XMP or IPTC unless asked to. Orientation is applied to the pixels
// first so a phone photo is not published sideways once its orientation tag is gone.
//
// Nothing here trusts itself: metadataFree() re-reads an output and is used twice — on the
// buffer before upload, and on the file fetched back from public storage.
import sharp from 'sharp'
import { readExifGps } from './exif-gps.mjs'

export const MAX_EDGE = 2400

export async function readOriginal(input) {
  const meta = await sharp(input).metadata()            // throws on anything that is not an image
  return {
    format: meta.format,                                 // jpeg | png | webp | ...
    gps: meta.exif ? readExifGps(meta.exif) : null,     // null = no location data, never a guess
  }
}

export async function stripForPublic(input) {
  const { data, info } = await sharp(input)
    .rotate()                                            // bake orientation into pixels
    .resize({ width: MAX_EDGE, height: MAX_EDGE, fit: 'inside', withoutEnlargement: true })
    .jpeg({ quality: 85, mozjpeg: true })
    .toBuffer({ resolveWithObject: true })
  const check = await metadataFree(data)
  if (!check.free) throw new Error('public copy still carries metadata: ' + check.found.join(', '))
  return { data, width: info.width, height: info.height }
}

// True only if the image carries no EXIF, XMP or IPTC block and no readable GPS.
export async function metadataFree(buf) {
  const m = await sharp(buf).metadata()
  const found = []
  if (m.exif) found.push('exif')
  if (m.xmp) found.push('xmp')
  if (m.iptc) found.push('iptc')
  if (m.exif && readExifGps(m.exif)) found.push('gps')
  return { free: found.length === 0, found }
}
