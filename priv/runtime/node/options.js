const { chromium, webkit, firefox } = require('playwright');

const baseHTTPHeaders = {
  'Accept-Language': 'en-US,en;q=0.9',
  'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
  'Connection': 'keep-alive',
  'Upgrade-Insecure-Requests': '1',
};

const getBrowser = async (type) => {
  switch (type) {
    case 'webkit':
      return webkit.launch()
      break;

    case 'firefox':
      return firefox.launch()
      break;

    default:
      return chromium.launch()
      break;
  }
}

const delay = ms => new Promise(resolve => setTimeout(resolve, ms))

module.exports = { baseHTTPHeaders, getBrowser, delay };

