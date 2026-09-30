export {}

export type LicenseStatus = 'active' | 'inactive' | 'expired' | 'revoked' | 'suspended'
export type Tier = 'public' | 'verified' | 'member'
export type SubscriptionTier = 'listed' | 'enhanced' | 'member'
export type ProfileTierLabel = 'Listed' | 'Claimed' | 'Enhanced' | 'Verified'
export interface ContractorMapPin {
  id: string
  slug: string
  display_name: string
  trade_label: string | null
  doc_category: string | null
  city: string | null
  state: string | null
  zip_code: string | null
  lat: number
  lng: number
  tier: Tier | null
  license_status: LicenseStatus | null
}
export interface Contractor {
  id: string
  slug: string
  business_name: string
  trading_name: string | null
  display_name: string
  trade_code: string | null
  trade_label: string | null
  doc_category: string | null
  classifications: string[] | null
  license_number: string | null
  license_status: LicenseStatus | null
  expiry_date: string | null
  address_line_1: string | null
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
  claimed: boolean | null
  active: boolean | null
  profile_score: number | null
  profile_tier_label: ProfileTierLabel | null
  source: string | null
  source_url: string | null
  subscription_tier: SubscriptionTier | null
  created_at: string | null
  updated_at: string | null
}
export interface BoundingBox {
  north: number
  south: number
  east: number
  west: number
}
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