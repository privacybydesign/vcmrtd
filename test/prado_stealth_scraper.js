/**
 * PRADO Stealth Scraper
 * Uses puppeteer-extra with stealth plugin to bypass Cloudflare
 *
 * Usage:
 *   npm install puppeteer-extra puppeteer-extra-plugin-stealth puppeteer
 *   node prado_stealth_scraper.js
 */

const puppeteer = require('puppeteer-extra');
const StealthPlugin = require('puppeteer-extra-plugin-stealth');
const fs = require('fs');
const path = require('path');

// Apply stealth plugin
puppeteer.use(StealthPlugin());

const BASE_URL = 'https://www.consilium.europa.eu/prado/en/prado-documents';
const IMAGE_BASE_URL = 'https://www.consilium.europa.eu/prado/images';
const OUTPUT_DIR = './prado_images';
const COOKIES_FILE = './prado_cookies.json';

// // Countries to scrape - All PRADO countries
// const COUNTRIES = [
//   // EU Member States
//   'EUE', 'AUT', 'BEL', 'BGR', 'CYP', 'CZE', 'DEU', 'DNK', 'ESP', 'EST',
//   'FIN', 'FRA', 'GRC', 'HRV', 'HUN', 'IRL', 'ITA', 'LTU', 'LUX', 'LVA',
//   'MLT', 'NLD', 'POL', 'PRT', 'ROU', 'SVK', 'SVN', 'SWE',
//   // Schengen Associates
//   'CHE', 'ISL', 'NOR', 'LIE',
//   // Other countries
//   'AFG', 'AGO', 'AIA', 'ALB', 'AND', 'ARE', 'ARG', 'ARM', 'AUS', 'AZE',
//   'BDI', 'BEN', 'BFA', 'BGD', 'BHR', 'BHS', 'BIH', 'BLR', 'BLZ', 'BMU',
//   'BRA', 'BRN', 'BTN', 'BWA', 'CAF', 'CAN', 'CHL', 'CHN', 'CIV', 'CMR',
//   'COD', 'COG', 'COL', 'COM', 'CPV', 'CRI', 'CUB', 'DJI', 'DMA', 'DOM',
//   'DZA', 'ECU', 'EGY', 'ERI', 'ETH', 'FRO', 'GAB', 'GBD', 'GBR', 'GEO',
//   'GGY', 'GHA', 'GIB', 'GIN', 'GMB', 'GNB', 'GNQ', 'GRD', 'GRL', 'GUY',
//   'HKG', 'HND', 'HTI', 'IMN', 'IND', 'IRN', 'IRQ', 'ISR', 'JAM', 'JEY',
//   'JOR', 'JPN', 'KAZ', 'KEN', 'KGZ', 'KHM', 'KNA', 'KOR', 'KWT', 'LAO',
//   'LBN', 'LBR', 'LBY', 'LKA', 'LSO', 'MAC', 'MAR', 'MCO', 'MDA', 'MDG',
//   'MDV', 'MEX', 'MKD', 'MLI', 'MNE', 'MNG', 'MOZ', 'MRT', 'MSR', 'MWI',
//   'MYS', 'NAM', 'NCL', 'NGA', 'NIC', 'NPL', 'NZL', 'OMN', 'PAK', 'PAN',
//   'PER', 'PHL', 'PLW', 'PRK', 'PRY', 'PYF', 'QAT', 'RUS', 'RWA', 'SAU',
//   'SDN', 'SEN', 'SGP', 'SHN', 'SLE', 'SLV', 'SMR', 'SOM', 'SRB', 'SSD',
//   'STP', 'SUR', 'SYC', 'SYR', 'TCA', 'TCD', 'TGO', 'THA', 'TKM', 'TLS',
//   'TUN', 'TUR', 'TUV', 'TWN', 'TZA', 'UGA', 'UKR', 'URY', 'USA', 'UZB',
//   'VAT', 'VEN', 'VGB', 'VNM', 'YEM', 'ZAF', 'ZMB', 'ZWE',
//   // Special entities
//   'INT', 'OPT', 'UAP', 'UNO', 'XEC', 'XKX', 'XOM', 'XPO'
// ];

// Countries to scrape - All PRADO countries
const COUNTRIES = [
  'GAB', 'GBD', 'GBR', 'GEO',
  'GGY', 'GHA', 'GIB', 'GIN', 'GMB', 'GNB', 'GNQ', 'GRD', 'GRL', 'GUY',
  'HKG', 'HND', 'HTI', 'IMN', 'IND', 'IRN', 'IRQ', 'ISR', 'JAM', 'JEY',
  'JOR', 'JPN', 'KAZ', 'KEN', 'KGZ', 'KHM', 'KNA', 'KOR', 'KWT', 'LAO',
  'LBN', 'LBR', 'LBY', 'LKA', 'LSO', 'MAC', 'MAR', 'MCO', 'MDA', 'MDG',
  'MDV', 'MEX', 'MKD', 'MLI', 'MNE', 'MNG', 'MOZ', 'MRT', 'MSR', 'MWI',
  'MYS', 'NAM', 'NCL', 'NGA', 'NIC', 'NPL', 'NZL', 'OMN', 'PAK', 'PAN',
  'PER', 'PHL', 'PLW', 'PRK', 'PRY', 'PYF', 'QAT', 'RUS', 'RWA', 'SAU',
  'SDN', 'SEN', 'SGP', 'SHN', 'SLE', 'SLV', 'SMR', 'SOM', 'SRB', 'SSD',
  'STP', 'SUR', 'SYC', 'SYR', 'TCA', 'TCD', 'TGO', 'THA', 'TKM', 'TLS',
  'TUN', 'TUR', 'TUV', 'TWN', 'TZA', 'UGA', 'UKR', 'URY', 'USA', 'UZB',
  'VAT', 'VEN', 'VGB', 'VNM', 'YEM', 'ZAF', 'ZMB', 'ZWE',
  // Special entities
  'INT', 'OPT', 'UAP', 'UNO', 'XEC', 'XKX', 'XOM', 'XPO'
];

// Document categories: A = passports, B = ID cards
const CATEGORIES = { A: 'passport', B: 'idcard' };

const DELAY_MIN = 3000;
const DELAY_MAX = 6000;

function randomDelay() {
  const delay = Math.floor(Math.random() * (DELAY_MAX - DELAY_MIN)) + DELAY_MIN;
  return new Promise(resolve => setTimeout(resolve, delay));
}

function randomViewport() {
  const widths = [1366, 1440, 1536, 1920];
  const heights = [768, 900, 864, 1080];
  const idx = Math.floor(Math.random() * widths.length);
  return {
    width: widths[idx] + Math.floor(Math.random() * 100),
    height: heights[idx] + Math.floor(Math.random() * 50)
  };
}

async function saveCookies(page) {
  const cookies = await page.cookies();
  fs.writeFileSync(COOKIES_FILE, JSON.stringify(cookies, null, 2));
  console.log('Cookies saved');
}

async function loadCookies(page) {
  if (fs.existsSync(COOKIES_FILE)) {
    const cookies = JSON.parse(fs.readFileSync(COOKIES_FILE));
    await page.setCookie(...cookies);
    console.log('Cookies loaded');
    return true;
  }
  return false;
}

async function waitForCloudflare(page) {
  const maxWait = 30000;
  const startTime = Date.now();

  while (Date.now() - startTime < maxWait) {
    const title = await page.title();

    if (title.includes('moment') || title.includes('Checking') || title.includes('Browser check')) {
      console.log('  Waiting for Cloudflare challenge...');
      await new Promise(r => setTimeout(r, 2000));
    } else {
      return true;
    }
  }

  console.log('  Cloudflare challenge timeout');
  return false;
}

async function extractDocuments(page, url) {
  console.log(`  Navigating to: ${url}`);

  await page.goto(url, { waitUntil: 'domcontentloaded', timeout: 60000 });

  const passed = await waitForCloudflare(page);
  if (!passed) return [];

  // Additional wait for dynamic content
  await randomDelay();

  const documents = await page.evaluate(() => {
    const docs = [];
    const links = document.querySelectorAll('a[href*="/image-"]');

    links.forEach(link => {
      const href = link.href;
      const img = link.querySelector('img');

      if (img) {
        const match = href.match(/([A-Z]{3}-[A-Z]{2}-\d+)\/image-(\d+)\.html/);
        if (match) {
          docs.push({
            docId: match[1],
            imageId: match[2],
            title: img.alt || img.title || match[1]
          });
        }
      }
    });

    return docs;
  });

  console.log(`  Found ${documents.length} document images`);
  return documents;
}

async function downloadImage(page, docId, imageId, outputPath) {
  const imageUrl = `${IMAGE_BASE_URL}/${docId}/${imageId}.jpg`;

  try {
    const response = await page.goto(imageUrl, { waitUntil: 'networkidle2', timeout: 30000 });

    if (response && response.ok()) {
      const buffer = await response.buffer();
      fs.writeFileSync(outputPath, buffer);
      console.log(`    Downloaded: ${path.basename(outputPath)} (${buffer.length} bytes)`);
      return true;
    }

    // Try uppercase .JPG
    const jpgUrl = imageUrl.replace('.jpg', '.JPG');
    const retryResponse = await page.goto(jpgUrl, { waitUntil: 'networkidle2', timeout: 30000 });

    if (retryResponse && retryResponse.ok()) {
      const buffer = await retryResponse.buffer();
      fs.writeFileSync(outputPath, buffer);
      console.log(`    Downloaded: ${path.basename(outputPath)} (${buffer.length} bytes)`);
      return true;
    }

    console.log(`    Failed: ${response ? response.status() : 'no response'}`);
  } catch (error) {
    console.log(`    Error: ${error.message}`);
  }

  return false;
}

async function processCountry(browser, countryCode, category) {
  const categoryName = CATEGORIES[category];
  const url = `${BASE_URL}/${countryCode}/${category}/O/docs-per-type.html`;

  console.log(`\nProcessing ${countryCode} - ${categoryName}`);

  const page = await browser.newPage();
  const viewport = randomViewport();
  await page.setViewport(viewport);

  let downloadCount = 0;

  try {
    // Load saved cookies
    await loadCookies(page);

    const documents = await extractDocuments(page, url);

    if (documents.length === 0) {
      return 0;
    }

    // Save cookies after successful page load
    await saveCookies(page);

    // Create output directory
    const outputDir = path.join(OUTPUT_DIR, countryCode, categoryName);
    if (!fs.existsSync(outputDir)) {
      fs.mkdirSync(outputDir, { recursive: true });
    }

    // Download images
    for (const doc of documents) {
      const outputPath = path.join(outputDir, `${doc.docId}_${doc.imageId}.jpg`);

      if (fs.existsSync(outputPath)) {
        console.log(`    Skipping (exists): ${path.basename(outputPath)}`);
        continue;
      }

      const success = await downloadImage(page, doc.docId, doc.imageId, outputPath);
      if (success) downloadCount++;

      await randomDelay();
    }

    return downloadCount;
  } finally {
    await page.close();
  }
}

async function main() {
  console.log('PRADO Stealth Scraper');
  console.log('=====================\n');
  console.log('Using puppeteer-extra-plugin-stealth to bypass Cloudflare\n');

  if (!fs.existsSync(OUTPUT_DIR)) {
    fs.mkdirSync(OUTPUT_DIR, { recursive: true });
  }

  const browser = await puppeteer.launch({
    headless: false, // Headed mode is less detectable
    args: [
      '--no-sandbox',
      '--disable-setuid-sandbox',
      '--disable-blink-features=AutomationControlled',
      '--disable-infobars',
      '--window-size=1920,1080'
    ],
    ignoreDefaultArgs: ['--enable-automation']
  });

  let totalDownloads = 0;

  try {
    for (let i = 0; i < COUNTRIES.length; i++) {
      const country = COUNTRIES[i];
      console.log(`\n[${i + 1}/${COUNTRIES.length}] Country: ${country}`);

      for (const category of Object.keys(CATEGORIES)) {
        const count = await processCountry(browser, country, category);
        totalDownloads += count;
        await randomDelay();
      }
    }
  } finally {
    await browser.close();
  }

  console.log('\n=====================');
  console.log(`Done! Downloaded ${totalDownloads} images`);
  console.log(`Output: ${path.resolve(OUTPUT_DIR)}`);
}

main().catch(console.error);
