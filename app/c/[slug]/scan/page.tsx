import { notFound } from 'next/navigation'
import { contractorSocket } from '@/lib/sockets/contractors'
import ScanLanding from '@/app/components/ScanLanding'

interface Props {
  params: Promise<{ slug: string }>
  searchParams: Promise<{ ref?: string }>
}

export default async function ScanPage({ params, searchParams }: Props) {
  const { slug } = await params
  const { ref } = await searchParams

  const c = await contractorSocket.forProfile(slug)
  if (!c) notFound()

  return (
    <ScanLanding
      slug={slug}
      displayName={c.display_name}
      tradeLabel={c.trade_label ?? 'Licensed Contractor'}
      city={c.city ?? ''}
      state={c.state ?? ''}
      tradeCategory={c.doc_category ?? ''}
      hasWebsite={false}
      websiteUrl={null}
      ref_={ref ?? 'qr'}
    />
  )
}