import type { Metadata } from 'next'
import { notFound } from 'next/navigation'
import StateRightsLanding from '@/app/components/StateRightsLanding'
import { legalSocket } from '@/lib/sockets/legal'

export async function generateStaticParams() {
  const states = await legalSocket.listVerifiedStates()
  return states.map(s => ({ state: s.slug }))
}

export async function generateMetadata({ params }: { params: Promise<{ state: string }> }): Promise<Metadata> {
  const { state: slug } = await params
  const state = await legalSocket.stateBySlug(slug)
  if (!state) return { title: 'Construction-defect rights by state' }
  const deadline = state.repose_years != null ? `${state.repose_years}-year deadline` : 'no statute of repose'
  const title = `${state.state_name} construction-defect deadline — your rights (${deadline})`
  const description =
    state.homeowner_summary ??
    `What you can still do about a construction defect in ${state.state_name}, the ${deadline}, and the one step to take today.`
  return {
    title,
    description,
    alternates: { canonical: `/rights/${state.slug}` },
    keywords: state.seo_keywords ?? undefined,
    openGraph: { title, description, url: `/rights/${state.slug}`, type: 'article' },
  }
}

export default async function Page({ params }: { params: Promise<{ state: string }> }) {
  const { state: slug } = await params
  const [state, all] = await Promise.all([
    legalSocket.stateBySlug(slug),
    legalSocket.listVerifiedStates(),
  ])
  if (!state) notFound()
  const compare = all.map(s => ({ slug: s.slug, state_name: s.state_name, repose_years: s.repose_years }))
  return <StateRightsLanding state={state} compare={compare} />
}
