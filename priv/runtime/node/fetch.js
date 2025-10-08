#!/usr/bin/env node

const { program } = require('commander');

const { baseHTTPHeaders, getBrowser } = require('./options');
const userAgent = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/123.0.0.0 Safari/537.36';

async function run(type, url, options) {
  const browser = await getBrowser(type)
  const extraHTTPHeaders = {
    ...baseHTTPHeaders,
    'User-Agent': options.user
  }

  const context = await browser.newContext({extraHTTPHeaders});
  await context.addInitScript(() => {
    Object.defineProperty(navigator, 'webdriver', { get: () => false });
  })

  const page     = await context.newPage();
  const response = await page.goto(url, { waitUntil: 'domcontentloaded' });
  const body     = await response.body()
  const text     = await response.text()
  await browser.close();
  console.log(text)
  return text
}

async function main() {
  program
    .name('Fetcher')
    .description('CLI to scrape with playwright')
    .argument('[url]', 'A valid url to working with')
    .option('-u, --user <user>', 'Additional headers you want to add', userAgent)
    .option('-b, --browser <browser>', 'Default browser to use', 'chromium')
    .action((url, options) => {
      try {
        const uri = new URL(url)
        run(options.browser, uri.toString(), options)
      } catch (error) {
        console.log('Error', {error})
      }
    })

  await program.parseAsync(process.argv)
};

main();
