export type LicenseStatus = 'active' | 'inactive' | 'expired' | 'revoked' | 'suspended'
export type Tier = 'public' | 'verified' | 'member'
export type SubscriptionTier = 'listed' | 'enhanced' | 'member'
export type ProfileTierLabel = 'Listed' | 'Claimed' | 'Enhanced' | 'Verified'

/** Minimal contractor record returned by map bounding-box API */
export interface ContractorMapPin {
  id: string
  slug: string
  display_name: string
  trade_label: string | null
  doc_category: string | null
  city: string | null
  state: string | null
  lat: number
  lng: number
  tier: Tier | null
  verified: boolean | null
  emergency_available: boolean | null
  license_status: LicenseStatus | null
}

/** Full contractor record for profile page */
export interface Contractor {
  id: string
  slug: string
  business_name: string
  trading_name: string | null
  display_name: string
  trade_code: string | null
  trade_label: string | null
  doc_category: string | null
  service_categories: string[] | null
  classifications: string[] | null
  license_number: string | null
  license_status: LicenseStatus | null
  expiry_date: string | null
  phone: string | null
  city: string | null
  state: string | null
  zip_code: string | null
  county_code: string | null
  country_code: string | null
  lat: number | null
  lng: number | null
  geocoded: boolean | null
  geocode_quality: string | null
  tier: Tier | null
  verified: boolean | null
  claimed: boolean | null
  active: boolean | null
  profile_score: number | null
  profile_tier_label: ProfileTierLabel | null
  source: string | null
  source_url: string | null
  subscription_tier: SubscriptionTier | null
  qr_code_url: string | null
  // Specialist capability flags
  ada_compliant_work: boolean | null
  aging_in_place: boolean | null
  chemical_sensitivity_aware: boolean | null
  mobility_accessible_worksite: boolean | null
  hurricane_hardening: boolean | null
  impact_window_certified: boolean | null
  roof_certification: boolean | null
  storm_restoration: boolean | null
  emergency_available: boolean | null
  emergency_plumbing: boolean | null
  emergency_roofing: boolean | null
  emergency_electrical: boolean | null
  emergency_storm_damage: boolean | null
  emergency_water_damage: boolean | null
  emergency_board_up: boolean | null
  emergency_response_hours: string | null
  created_at: string | null
  updated_at: string | null
}

export interface BoundingBox {
  north: number
  south: number
  east: number
  west: number
}

/** Trade categories for filter chips */
export const TRADE_CATEGORIES = [
  { value: 'general_contractor', label: 'General Contractor' },
  { value: 'roofing', label: 'Roofing' },
  { value: 'plumbing', label: 'Plumbing' },
  { value: 'hvac', label: 'HVAC' },
  { value: 'electrical', label: 'Electrical' },
  { value: 'painting', label: 'Painting' },
  { value: 'flooring', label: 'Flooring' },
  { value: 'masonry', label: 'Masonry' },
  { value: 'pool', label: 'Pool' },
  { value: 'landscaping', label: 'Landscaping' },
  { value: 'solar', label: 'Solar' },
  { value: 'windows_doors', label: 'Windows & Doors' },
  { value: 'insulation', label: 'Insulation' },
  { value: 'drywall', label: 'Drywall' },
  { value: 'concrete', label: 'Concrete' },
] as const
