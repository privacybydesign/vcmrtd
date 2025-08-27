import type {SidebarsConfig} from '@docusaurus/plugin-content-docs';

// This runs in Node.js - Don't use client-side code here (browser APIs, JSX...)

/**
 * Creating a sidebar enables you to:
 - create an ordered group of docs
 - render a sidebar for each doc of that group
 - provide next/previous navigation

 The sidebars can be generated from the filesystem, or explicitly defined here.

 Create as many sidebars as you want.
 */
const sidebars: SidebarsConfig = {
  // By default, Docusaurus generates a sidebar from the docs folder structure
  docSidebar: [
    {
      type: 'category',
      label: 'Overview',
      collapsed: false,
      items: [
        'index'
      ],
    },
    {
      type: 'category',
      label: 'Example Mobile Application',
      collapsed: false,
      items: [
        'dmrtd/app',
        // 'dmrtd/usage',
        // 'dmrtd/advanced-usage',
        // 'dmrtd/faq'
      ],
    },
    {
      type: 'category',
      label: 'Passport based Veriable Credentials',
      collapsed: false,
      items: [
        'library/support',
        'library/flow',
      ],
    },
    {
      type: 'category',
      label: 'Background information',
      collapsed: false,
      items: [
        'info/aa',
        'info/bac',
        'info/pace',
        'info/pa',
        'info/standards',
        'info/pki',
      ],
    }
  ],

  // But you can create a sidebar manually

};

export default sidebars;
