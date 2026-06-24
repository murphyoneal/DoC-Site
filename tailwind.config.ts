import type { Config } from 'tailwindcss'

const config: Config = {
  content: [
    './pages/**/*.{js,ts,jsx,tsx,mdx}',
    './components/**/*.{js,ts,jsx,tsx,mdx}',
    './app/**/*.{js,ts,jsx,tsx,mdx}',
  ],
  theme: {
    extend: {
      colors: {
        ink:    '#1C1C1C',
        bronze: '#8B6F47',
        sage:   '#6B7F6B',
        cream:  '#FAF7F2',
        navy:   '#1B2A4A',
        gold:   '#C9A84C',
        'light-gray': '#F0EDEA',
      },
      fontFamily: {
        display: ['Georgia', 'Times New Roman', 'serif'],
        body:    ['Arial', 'system-ui', 'sans-serif'],
        mono:    ['Courier New', 'monospace'],
      },
    },
  },
  plugins: [],
}
export default config
