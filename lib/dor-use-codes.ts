// Florida DOR (Department of Revenue) land-use codes. parcels_staging.dor_uc holds
// only the raw code; there's no description column in the DB, so this is the lookup.
// Subset of the standard FL DOR code table — extend as needed.
// TODO(murphy): confirm/complete against the official DOR code list if the assistant
// needs codes beyond these common ones.
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

export function landUseLabel(code: string | null | undefined): string {
  if (!code) return 'Unknown'
  const key = String(code).trim().padStart(3, '0')
  return DOR_USE_CODES[key] ?? `DOR code ${code}`
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
