import TradingViewHook from './hooks/trading_view'
import ChoicesHook from './hooks/choices'
import ModalOpenerHook from './hooks/modal'

const CounterFormatter = {
  mounted() {
    const num = this.el.innerText
    const val = parseInt(num)
    this.el.innerText = numeral(val).format('0a')
  }
}

const TogglerHook = {
  mounted() {
    this.el.addEventListener('change', () => {
      const t = document.querySelector(this.el.dataset.target)
      const c = this.el.dataset.class || 'block'

      if (!t) return

      if (this.el.value && this.el.value != '') {
        t.classList.add(c)
        t.classList.remove('hidden')
      } else {
        t.classList.remove(c)
        t.classList.add('hidden')
      }
    })
  }
}

export { TradingViewHook, CounterFormatter, ChoicesHook, ModalOpenerHook, TogglerHook }
