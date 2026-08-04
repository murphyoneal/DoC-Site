// Renders a schema.org JSON-LD <script>. Server component — safe to embed in
// any page's markup for structured data.
export default function JsonLd({ data }: { data: Record<string, unknown> }) {
  return (
    <script
      type="application/ld+json"
      dangerouslySetInnerHTML={{ __html: JSON.stringify(data) }}
    />
  )
}
