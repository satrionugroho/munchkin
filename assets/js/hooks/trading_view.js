const TradingViewHook = {
  mounted() {
    const symbol = this.el.dataset.symbol
    const script = document.createElement("script")
    script.src = "https://s3.tradingview.com/external-embedding/embed-widget-advanced-chart.js";
		  script.type = "text/javascript";
		  script.async = true;
    script.innerHTML = `
			{
        "allow_symbol_change": false,
        "calendar": false,
        "details": false,
        "hide_side_toolbar": true,
        "hide_top_toolbar": false,
        "hide_legend": false,
        "hide_volume": false,
        "hotlist": false,
        "interval": "D",
        "locale": "en",
        "style": "1",
        "symbol": "${symbol}",
        "theme": "dark",
        "backgroundColor": "#0F0F0F",
        "gridColor": "rgba(242, 242, 242, 0.06)",
        "watchlist": [],
        "withdateranges": false,
        "compareSymbols": [],
        "studies": [
          "STD;Divergence%1Indicator",
          "STD;MA%1Cross"
        ],
        "autosize": true,
			  "support_host": "https://www.tradingview.com",
			  "timezone": "exchange",
			  "save_image": false,
			  "show_popup_button": false
			}`;
    this.el.appendChild(script)

    setTimeout(() => {
      this.el.style.height = '50vh'
    }, 200)
  },
}

export default TradingViewHook
