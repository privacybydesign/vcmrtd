import {themes as prismThemes} from 'prism-react-renderer';
import type {Config} from '@docusaurus/types';
import type * as Preset from '@docusaurus/preset-classic';

const config: Config = {
  title: "VCMRTD Documentation",
  tagline: "Read and verify Machine Readable Travel Documents via NFC",
  favicon: "img/favicon.ico",
  future: {
    v4: true,
  },

  url: "https://privacybydesign.github.io/",
  baseUrl: "/vcmrtd/",
  trailingSlash: false,
  organizationName: "privacybydesign",
  projectName: "vcmrtd",
  deploymentBranch: "gh-pages",

  onBrokenLinks: "throw",
  onBrokenMarkdownLinks: "warn",

  staticDirectories: ["static"],

  i18n: {
    defaultLocale: "en",
    locales: ["en"],
  },

  presets: [
    [
      "classic",
      {
        docs: {
          sidebarPath: "./sidebars.ts",
          routeBasePath: "/",
        },
        blog: false,
        theme: {
          customCss: "./src/css/custom.css",
        },
      } satisfies Preset.Options,
    ],
  ],

  markdown: {
    mermaid: true,
  },
  themes: ['@docusaurus/theme-mermaid'],
  themeConfig: {
    navbar: {
      title: "VCMRTD",
      items: [
        {
          type: "docSidebar",
          sidebarId: "docSidebar",
          position: "left",
          label: "Documentation",
        },
        {
          href: "https://github.com/privacybydesign/vcmrtd",
          label: "GitHub",
          position: "right",
        },
      ],
    },
    footer: {
      style: "dark",
      links: [
        {
          title: "Documentation",
          items: [
            {
              label: "Getting Started",
              to: "/getting-started",
            },
            {
              label: "Integration Guide",
              to: "/integration",
            },
          ],
        },
        {
          title: "Related Projects",
          items: [
            {
              label: "go-passport-issuer",
              href: "https://github.com/privacybydesign/go-passport-issuer",
            },
            {
              label: "GMRTD",
              href: "https://github.com/gmrtd/gmrtd",
            },
            {
              label: "Yivi",
              href: "https://yivi.app",
            },
          ],
        },
        {
          title: "More",
          items: [
            {
              label: "GitHub",
              href: "https://github.com/privacybydesign/vcmrtd",
            },
            {
              label: "Privacy by Design Foundation",
              href: "https://privacybydesign.foundation",
            },
          ],
        },
      ],
      copyright: `Copyright ${new Date().getFullYear()} Yivi B.V. Built with Docusaurus.`,
    },
    prism: {
      theme: prismThemes.github,
      darkTheme: prismThemes.dracula,
      additionalLanguages: ['dart', 'yaml', 'json'],
    },
  } satisfies Preset.ThemeConfig,
};

export default config;
