import type {SidebarsConfig} from '@docusaurus/plugin-content-docs';

const sidebars: SidebarsConfig = {
  docSidebar: [
    'index',
    'getting-started',
    'integration',
    {
      type: 'category',
      label: 'Example Application',
      collapsed: false,
      items: [
        'example/overview',
        'example/usage',
      ],
    },
    {
      type: 'category',
      label: 'API Reference',
      collapsed: false,
      items: [
        'api/backend',
      ],
    },
    {
      type: 'category',
      label: 'Technical Reference',
      collapsed: true,
      items: [
        'reference/standards',
        'reference/authentication',
        'reference/data-groups',
        'reference/pki',
      ],
    },
  ],
};

export default sidebars;
