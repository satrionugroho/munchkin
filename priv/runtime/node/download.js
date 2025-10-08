#!/usr/bin/env node

const { mkdtemp } = require('node:fs/promises');
const { join } = require('node:path');
const { tmpdir } = require('node:os')
const { program } = require('commander');
const { baseHTTPHeaders, getBrowser, delay } = require('./options');

const userAgent = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/123.0.0.0 Safari/537.36';

async function run(type, url, options) {
  const mockURL = `https://www.idx.co.id/id/perusahaan-tercatat/profil-perusahaan-tercatat/${options.ticker}`
  const browser = await getBrowser(type)
  const timeout = parseInt(options.timeout)
  const extraHTTPHeaders = {
    ...baseHTTPHeaders,
    'User-Agent': options.user
  }

  const context = await browser.newContext({extraHTTPHeaders});
  await context.addInitScript(() => {
    Object.defineProperty(navigator, 'webdriver', { get: () => false });
  })

  const page     = await context.newPage();
  const promise  = page.waitForEvent('download', {timeout})
  const response = await page.goto(mockURL, { waitUntil: 'domcontentloaded' });
  if (!response.ok()) {
    const text = await response.text()
    console.error('URL cannot Loaded', { text })
    await browser.close()
    return
  }

  page.evaluate(url => {
    window.location=url
  }, url.toString())
  const download = await promise
  const suggestedFilename = download.suggestedFilename()
  const downloadFolder = await mkdtemp(join(tmpdir(), "munchkin"))
  const filePath = join(downloadFolder, suggestedFilename)
  await download.saveAs(filePath)
  await browser.close()

  const result = {
    file: filePath,
    message: 'Successfully downloaded'
  }

  console.log(JSON.stringify(result))
  return JSON.stringify(result)
}

async function main() {
  program
    .name('Fetcher')
    .description('CLI to scrape with playwright')
    .argument('[url]', 'A valid url to working with')
    .option('-u, --user <user>', 'Additional headers you want to add', userAgent)
    .option('-t, --ticker <ticker>', 'Additional ticker', 'BBCA')
    .option('-b, --browser <browser>', 'Default browser to use', 'chromium')
    .option('-o, --timeout <timeout>', 'Default browser to use', '10000')
    .action((url, options) => {
      try {
        const uri = new URL(url)
        run(options.browser, uri, options)
      } catch (error) {
        console.log('Error', {error})
      }
    })

  await program.parseAsync(process.argv)
};

main();
