// Florida DOR (Department of Revenue) land-use codes. parcels_staging.dor_uc holds
// only the raw code; there's no description column in the DB, so this is the lookup.
// Subset of the standard FL DOR code table — extend as needed.
//
// SIZED 15 Aug 2026: this table holds 59 codes. parcels_staging carries 100
// distinct dor_uc values, so 41 are unlabelled here, covering 272,914 parcels
// (2.54% of 10,739,881 with a code). Largest gaps: 087 (56,038), 055 (32,436),
// 050 (26,273), 056 (25,385), 061 (20,942).
//
// TODO(murphy): complete this from the OFFICIAL published DOR code list and cite
// it in this comment. Do NOT fill the gaps from recall — an unsourced definition
// is the defect this file just caused. Until then landUseLabel() says "undefined"
// for the 41, which is honest and safe; it is not a substitute for the real list.
const DOR_USE_CODES: Record<string, string> = {
  '000': 'Vacant Residential',
  '001': 'Single Family',
  '002': 'Mobile Home',
  '003': 'Multi-Family (10+ units)',
  '004': 'Condominium',
  '005': 'Cooperative',
  '006': 'Retirement Home',
  '007': 'Miscellaneous Residential',
  '008': 'Multi-Family (<10 units)',
  '009': 'Residential Common Element',
  '010': 'Vacant Commercial',
  '011': 'Stores, One Story',
  '012': 'Mixed Use (Store + Office/Residential)',
  '013': 'Department Store',
  '014': 'Supermarket',
  '015': 'Regional Shopping Center',
  '016': 'Community Shopping Center',
  '017': 'Office, One Story',
  '018': 'Office, Multi-Story',
  '019': 'Professional Building',
  '020': 'Airport / Bus / Marine Terminal',
  '021': 'Restaurant / Cafeteria',
  '022': 'Drive-in Restaurant',
  '023': 'Financial Institution',
  '024': 'Insurance Company Office',
  '025': 'Repair Service Shop',
  '026': 'Service Station',
  '027': 'Auto Sales / Service',
  '028': 'Parking Lot / Mobile Home Park',
  '033': 'Nightclub / Bar',
  '038': 'Golf Course',
  '039': 'Hotel / Motel',
  '040': 'Vacant Industrial',
  '041': 'Light Manufacturing',
  '048': 'Warehouse / Distribution',
  '049': 'Open Storage',
  '051': 'Cropland (Soil Class I)',
  '060': 'Grazing Land',
  '066': 'Orchard / Grove / Citrus',
  '068': 'Dairy / Feed Lot',
  '069': 'Ornamentals / Nursery',
  '070': 'Vacant Institutional',
  '071': 'Church',
  '072': 'Private School / College',
  '073': 'Private Hospital',
  '074': 'Home for the Aged',
  '075': 'Orphanage / Non-profit Service',
  '076': 'Mortuary / Cemetery',
  '077': 'Club / Lodge / Hall',
  '080': 'Vacant Governmental',
  '082': 'Forest / Park / Recreational',
  '083': 'Public County School',
  '086': 'County (other than schools)',
  '089': 'Municipal (other than parks/schools)',
  '091': 'Utility (gas/electric/water)',
  '094': 'Right-of-Way / Street / Road',
  '095': 'Rivers / Lakes / Submerged Land',
  '096': 'Sewage Disposal / Waste Land',
  '099': 'Acreage Not Zoned Agricultural',
}

/**
 * Label for a DOR use code — or an explicit statement that we do not hold one.
 *
 * DEFECT roz-glosses-opaque-codes-with-invented-meaning (15 Aug 2026).
 * This returned a bare `DOR code 092`. That string reads like a label with a
 * missing word, so the narrator supplied one: it rendered DOR 092 as
 * "utility/land classification" — almost certainly by analogy with the adjacent
 * '091': 'Utility (gas/electric/water)'. The county source for that parcel says
 * MING/PETRO/GASLND. An invented definition, same mechanism as the seven
 * elevations: a value with no provenance reads as authoritative.
 *
 * MEASURED, not assumed: 41 of the 100 distinct dor_uc values in parcels_staging
 * have no entry in this table, covering 272,914 parcels (2.54%). Every one of
 * them was a gloss surface.
 *
 * The fix is NOT to add 092 from memory — writing a definition we cannot source
 * is the same defect with a different author. It is to say plainly that the code
 * is undefined here, so there is no gap for the model to fill.
 */
export function landUseLabel(code: string | null | undefined): string {
  if (!code) return 'Unknown'
  const key = String(code).trim().padStart(3, '0')
  const known = DOR_USE_CODES[key]
  if (known) return known
  return `DOR code ${key} — no description held; meaning UNDEFINED, do not infer it`
}

/** True when we hold no description for this code (callers that need the raw form). */
export function isUnlabelledDorCode(code: string | null | undefined): boolean {
  if (!code) return false
  return !(String(code).trim().padStart(3, '0') in DOR_USE_CODES)
}

// Reverse lookup for search filters — lets the assistant filter by a label the user
// says ("single family") back to the code the DB stores.
export function labelToDorCode(label: string): string | null {
  const q = label.trim().toLowerCase()
  for (const [code, name] of Object.entries(DOR_USE_CODES)) {
    if (name.toLowerCase() === q) return code
  }
  // loose contains match (e.g. "single family homes")
  for (const [code, name] of Object.entries(DOR_USE_CODES)) {
    if (name.toLowerCase().includes(q) || q.includes(name.toLowerCase())) return code
  }
  return null
}
