import { useRef } from "react"
import LiquidEther from "@/components/LiquidEther"
import BlurText from "@/components/BlurText"
import Aurora from "@/components/Aurora"
import { AnimatedBeam } from "@/components/ui/animated-beam"
import { BorderBeam } from "@/components/ui/border-beam"
import { MagicCard } from "@/components/ui/magic-card"
import { LampContainer } from "@/components/ui/lamp"
import Footer from "@/components/monet/Footer"

const GH = "https://github.com/ethembeldagli"
const REPO = `${GH}/millennium-bazzite`
const INSTALL = "curl -fsSL https://raw.githubusercontent.com/ethembeldagli/millennium-bazzite/main/install.sh | sh"

function Command() {
  return (
    <button onClick={() => navigator.clipboard?.writeText(INSTALL)} className="mono relative mx-auto block max-w-full overflow-hidden rounded-xl border border-white/10 bg-black/50 px-5 py-3 text-left text-[13px] text-white/80 backdrop-blur hover:text-white">
      <span className="text-[#9d8cff]">$</span> <span className="break-all">{INSTALL}</span>
      <BorderBeam size={90} duration={7} colorFrom="#9d8cff" colorTo="#ff7ae0" />
    </button>
  )
}

const Node = ({ r, label, sub }: { r: React.RefObject<HTMLDivElement | null>; label: string; sub: string }) => (
  <div ref={r} className="z-10 flex w-40 flex-col items-center rounded-2xl border border-white/10 bg-[#0c0b1f] px-4 py-3 text-center shadow-[0_0_40px_-12px_#9d8cff]">
    <span className="text-sm font-medium">{label}</span>
    <span className="mono mt-1 text-[11px] text-white/50">{sub}</span>
  </div>
)

export default function App() {
  const box = useRef<HTMLDivElement>(null)
  const steam = useRef<HTMLDivElement>(null)
  const desk = useRef<HTMLDivElement>(null)
  const game = useRef<HTMLDivElement>(null)
  const mill = useRef<HTMLDivElement>(null)
  const decky = useRef<HTMLDivElement>(null)

  return (
    <main className="overflow-x-hidden">
      {/* hero */}
      <section className="relative flex min-h-svh flex-col items-center justify-center px-6 text-center">
        <div className="absolute inset-0"><LiquidEther colors={["#5227FF", "#FF9FFC", "#B19EEF"]} autoDemo autoSpeed={0.45} autoIntensity={2.0} resolution={0.5} className="h-full w-full" /></div>
        <div className="pointer-events-none relative z-10">
          <p className="mono inline-block rounded-full border border-white/15 bg-black/30 px-3 py-1 text-[11px] uppercase tracking-[0.25em] text-white/70 backdrop-blur">Unofficial · for Bazzite</p>
          <BlurText text="Steam, re-skinned." animateBy="words" delay={140} className="serif mt-6 justify-center text-[clamp(3.5rem,11vw,10rem)] leading-[0.9] tracking-tight" />
          <p className="mx-auto mt-6 max-w-xl text-lg text-white/75">Millennium's themes and plugins on Bazzite. One command, no root, and it's still there after every system update.</p>
        </div>
        <div className="relative z-10 mt-10 w-full max-w-3xl"><Command /></div>
        <a href={REPO} className="mono relative z-10 mt-5 text-xs text-white/60 underline underline-offset-4 hover:text-white">Source on GitHub →</a>
      </section>

      {/* honesty first */}
      <section className="border-y border-white/10 bg-[#0a0918] px-6 py-6">
        <p className="mx-auto max-w-4xl text-center text-sm text-white/70">
          <strong className="text-white">This is not official Millennium.</strong> It's a community installer, not made by, affiliated with, or endorsed by the{" "}
          <a className="underline" href="https://github.com/SteamClientHomebrew/Millennium">Millennium project (Steam Homebrew)</a>, Valve, or Universal Blue. It installs Millennium's own releases, unchanged.
        </p>
      </section>

      {/* the split */}
      <LampContainer className="min-h-0 bg-[#05050f] pt-56">
        <h2 className="serif text-center text-5xl md:text-7xl">Two modes. <em>No fights.</em></h2>
        <p className="mx-auto mt-4 max-w-xl text-center text-white/70">Millennium and Decky Loader can't share one Steam session. So each gets its own mode, switched automatically.</p>
      </LampContainer>
      <section className="px-6 pb-28">
        <div ref={box} className="relative mx-auto flex max-w-3xl items-center justify-between gap-6">
          <div className="flex flex-col gap-16"><Node r={desk} label="Desktop Mode" sub="login" /><Node r={game} label="Game Mode" sub="gamescope" /></div>
          <Node r={steam} label="Steam" sub="same install" />
          <div className="flex flex-col gap-16"><Node r={mill} label="Millennium" sub="themes · plugins" /><Node r={decky} label="Decky Loader" sub="quick access" /></div>
          <AnimatedBeam containerRef={box} fromRef={desk} toRef={steam} curvature={-40} gradientStartColor="#9d8cff" gradientStopColor="#ff7ae0" />
          <AnimatedBeam containerRef={box} fromRef={game} toRef={steam} curvature={40} gradientStartColor="#3ee6ff" gradientStopColor="#9d8cff" />
          <AnimatedBeam containerRef={box} fromRef={steam} toRef={mill} curvature={40} gradientStartColor="#ff7ae0" gradientStopColor="#9d8cff" />
          <AnimatedBeam containerRef={box} fromRef={steam} toRef={decky} curvature={-40} gradientStartColor="#9d8cff" gradientStopColor="#3ee6ff" />
        </div>
      </section>

      {/* the installer itself */}
      <section className="px-6 pb-28">
        <div className="mx-auto max-w-5xl text-center">
          <p className="mono text-xs uppercase tracking-[0.3em] text-[#9d8cff]">The installer</p>
          <h2 className="serif mt-3 text-5xl md:text-6xl">Run it again any time.</h2>
          <p className="mx-auto mt-3 max-w-xl text-white/70">An animated menu to update, switch modes or remove it. Or just type <span className="mono text-white">millennium-bazzite</span>.</p>
          <div className="relative mt-10 overflow-hidden rounded-2xl border border-white/10">
            <img src="./installer.gif" alt="The animated installer menu: status, update, reinstall, Game Mode toggle and delete, then a progress bar and sparkles on success" className="w-full" />
            <BorderBeam size={220} duration={10} colorFrom="#5227FF" colorTo="#FF9FFC" />
          </div>
        </div>
      </section>

      {/* why */}
      <section className="px-6 pb-32">
        <div className="mx-auto grid max-w-5xl gap-4 md:grid-cols-2">
          {[
            ["No root", "Everything goes into your home folder. No sudo, no unlocking /usr."],
            ["Survives updates", "Bazzite can rebase and update as it likes; Millennium is still there."],
            ["Updates itself", "New Millennium releases install in the background, then Steam lets you know."],
            ["Keeps Decky", "Game Mode stays stock, so your Decky plugins keep working."],
          ].map(([t, d]) => (
            <MagicCard key={t} gradientFrom="#9d8cff" gradientTo="#ff7ae0" className="rounded-2xl p-8">
              <h3 className="serif text-4xl">{t}</h3>
              <p className="mt-2 text-white/70">{d}</p>
            </MagicCard>
          ))}
        </div>
      </section>

      {/* closing */}
      <section className="relative overflow-hidden px-6 py-40 text-center">
        <div className="absolute inset-0 opacity-80"><Aurora colorStops={["#5227FF", "#FF9FFC", "#3ee6ff"]} amplitude={1.1} blend={0.6} speed={0.6} className="h-full w-full" /></div>
        <div className="relative z-10">
          <h2 className="serif text-6xl md:text-8xl">Make Steam <em>yours</em>.</h2>
          <div className="mx-auto mt-10 max-w-3xl"><Command /></div>
        </div>
      </section>

      <Footer mode="dark" companyName="Ethem Beldagli · unofficial, not affiliated with Steam Homebrew" columns={[
        { title: "Project", links: [{ label: "Source", href: REPO, external: true }, { label: "Report a problem", href: `${REPO}/issues`, external: true }, { label: "MIT licence", href: `${REPO}/blob/main/LICENSE`, external: true }] },
        { title: "Millennium", links: [{ label: "Official project", href: "https://github.com/SteamClientHomebrew/Millennium", external: true }, { label: "Themes and plugins", href: "https://steambrew.app", external: true }] },
        { title: "Also by me", links: [{ label: "Terminal Wrapped", href: `${GH}/termwrapped`, external: true }, { label: "roastfetch", href: `${GH}/roastfetch`, external: true }] },
      ]} legalLinks={[{ label: "Not affiliated with Valve or Universal Blue", href: REPO }]} />
    </main>
  )
}
