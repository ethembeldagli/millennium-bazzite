"use client";

// ============================================================================
// CUSTOMIZATION - 이 섹션의 값들을 수정하여 프로젝트에 맞게 조정하세요
// ============================================================================

/**
 * 커스텀 색상 (브랜드 컬러)
 */
const COLORS = {
  background: "#0c0c0c",
  text: "#ffffff",
  textMuted: "#999999",
} as const;

// ============================================================================
// END CUSTOMIZATION
// ============================================================================

import { motion } from "motion/react";

interface FooterLink {
  label: string;
  href: string;
  external?: boolean;
}

interface FooterColumn {
  title: string;
  links: FooterLink[];
}

interface RunwaymlComFooter7Props {
  mode?: "light" | "dark";
  columns?: FooterColumn[];
  companyName?: string;
  year?: number;
  legalLinks?: FooterLink[];
}

const defaultColumns: FooterColumn[] = [
  {
    title: "Product",
    links: [
      { label: "GWM-1", href: "#" },
      { label: "General World Models", href: "#" },
      { label: "Robotics SDK", href: "#" },
      { label: "Gen-4.5", href: "#" },
      { label: "Aleph", href: "#" },
      { label: "Act-Two", href: "#" },
      { label: "API", href: "#" },
    ],
  },
  {
    title: "Initiatives",
    links: [
      { label: "Studios", href: "#" },
      { label: "AI Film Festival", href: "#", external: true },
      { label: "Gen:48", href: "#" },
      { label: "FOOM!", href: "#", external: true },
      { label: "Academy", href: "#", external: true },
      { label: "Telescope Magazine", href: "#", external: true },
      { label: "Creative Partners Program", href: "#" },
      { label: "The Hundred Film Fund", href: "#" },
    ],
  },
  {
    title: "Company",
    links: [
      { label: "Our Research", href: "#" },
      { label: "Publications", href: "#" },
      { label: "Careers", href: "#" },
      { label: "About Us", href: "#" },
      { label: "Customer Stories", href: "#" },
      { label: "News", href: "#" },
      { label: "Store", href: "#", external: true },
      { label: "Talent Network", href: "#", external: true },
    ],
  },
  {
    title: "Get Started",
    links: [
      { label: "For Enterprises", href: "#" },
      { label: "For Education", href: "#" },
      { label: "Login", href: "#" },
      { label: "Pricing", href: "#" },
      { label: "Help Center", href: "#", external: true },
      { label: "Data Security", href: "#" },
      { label: "Changelog", href: "#" },
    ],
  },
  {
    title: "Connect",
    links: [
      { label: "Press", href: "#" },
      { label: "Partnerships", href: "#" },
      { label: "Brand Guidelines", href: "#" },
      { label: "Meetups", href: "#" },
      { label: "Twitter", href: "#", external: true },
      { label: "Instagram", href: "#", external: true },
      { label: "YouTube", href: "#", external: true },
      { label: "Discord", href: "#", external: true },
    ],
  },
];

const defaultLegalLinks: FooterLink[] = [
  { label: "Terms of Use", href: "#" },
  { label: "Privacy Policy", href: "#" },
  { label: "California Notices", href: "#" },
  { label: "Code of Conduct", href: "#" },
  { label: "System Status", href: "#", external: true },
];


function PrivacyChoicesIcon({ className }: { className?: string }) {
  return (
    <svg
      width="25"
      viewBox="0 0 390 187"
      fill="none"
      xmlns="http://www.w3.org/2000/svg"
      className={className}
    >
      <path
        fillRule="evenodd"
        clipRule="evenodd"
        d="M296.334 0C347.001 0 389.667 41.4071 389.667 93.5C389.667 145.593 348.334 187 296.334 187H93.667C41.6671 187 0.333986 145.593 0.333984 93.5C0.333984 41.4072 41.6671 0.000171628 93.667 0H296.334ZM93.667 16.0283C51.0005 16.0285 16.334 50.7573 16.334 93.5C16.334 136.243 51.0005 170.972 93.667 170.972H184.334L225.667 16.0283H93.667ZM323.001 53.4287C320.334 50.7573 315.001 50.7573 312.334 53.4287L283.001 82.8145L253.668 53.4287C251.001 50.7573 245.668 50.7573 243.001 53.4287C240.334 56.1001 240.334 61.4428 243.001 64.1143L272.334 93.5L244.334 122.886C241.668 125.557 241.668 130.9 244.334 133.571C247.001 136.243 252.334 136.243 255.001 133.571L284.334 104.186L313.668 133.571C316.335 136.243 321.667 136.243 324.334 133.571C327.001 130.9 327.001 125.557 324.334 122.886L295.001 93.5L323.001 64.1143C325.668 61.4428 325.668 56.1001 323.001 53.4287Z"
        className="fill-current"
      />
      <path
        d="M164.334 54.7643C167.001 57.4357 168.334 62.7786 165.667 65.45L109.667 130.9C108.334 132.236 107.001 133.571 105.667 133.571C103.001 134.907 99.0006 134.907 96.334 132.236L67.0006 102.85C64.334 100.179 64.334 94.8357 67.0006 92.1643C69.6673 89.4929 75.0006 89.4929 77.6673 92.1643L101.667 114.871L152.334 54.7643C155.001 52.0929 160.334 52.0929 164.334 54.7643Z"
        className="fill-current"
      />
    </svg>
  );
}

export default function RunwaymlComFooter7({
  mode = "dark",
  columns = defaultColumns,
  companyName = "Ethem Beldagli",
  year = new Date().getFullYear(),
  legalLinks = defaultLegalLinks,
}: RunwaymlComFooter7Props) {
  void mode;
  return (
    <footer
      className="text-white pt-10 min-[1600px]:pt-28"
      style={{ backgroundColor: COLORS.background }}
    >
      <div className="max-w-[1440px] mx-auto px-6 lg:px-12">
        <div className="flex justify-between items-start">
          <motion.div
            initial={{ opacity: 0, y: 20 }}
            whileInView={{ opacity: 1, y: 0 }}
            viewport={{ once: true }}
            transition={{ duration: 0.6 }}
            className="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-5 gap-10 lg:gap-8 mb-32 lg:mb-52 flex-1"
          >
            {columns.map((column, columnIndex) => (
              <motion.div
                key={column.title}
                initial={{ opacity: 0, y: 20 }}
                whileInView={{ opacity: 1, y: 0 }}
                viewport={{ once: true }}
                transition={{ duration: 0.4, delay: columnIndex * 0.1 }}
              >
                <div
                  className="text-xs uppercase tracking-wider mb-4"
                  style={{ color: COLORS.textMuted }}
                >
                  {column.title}
                </div>
                <ul className="flex flex-col items-start">
                  {column.links.map((link) => (
                    <li key={link.label} className="text-sm mb-1">
                      <a
                        href={link.href}
                        target={link.external ? "_blank" : "_self"}
                        rel={link.external ? "noopener noreferrer" : undefined}
                        className="hover:underline transition-opacity hover:opacity-80"
                        style={{ color: COLORS.text }}
                      >
                        {link.label}
                        {link.external && (
                          <span className="text-[13px] ml-0.5">↗</span>
                        )}
                      </a>
                    </li>
                  ))}
                </ul>
              </motion.div>
            ))}
          </motion.div>
        </div>

        <motion.div
          initial={{ opacity: 0 }}
          whileInView={{ opacity: 1 }}
          viewport={{ once: true }}
          transition={{ duration: 0.6, delay: 0.3 }}
          className="flex flex-col lg:flex-row justify-between items-start lg:items-end pb-6"
        >
          <div className="flex flex-col lg:flex-row items-start lg:items-center">
            <span className="mb-2.5 lg:mr-28 text-white serif text-3xl leading-none">Millennium<br />for Bazzite</span>
            <div
              className="text-[10px] uppercase tracking-wider leading-relaxed"
              style={{ color: COLORS.textMuted }}
            >
              <span>
                &copy; {year} {companyName}
              </span>
              {legalLinks.slice(0, 3).map((link, index) => (
                <span key={link.label}>
                  {" "}
                  /{" "}
                  
                </span>
              ))}
            </div>
          </div>
        </motion.div>
      </div>
    </footer>
  );
}
