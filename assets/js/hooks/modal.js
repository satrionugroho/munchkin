const ModalOpenerHook = {
  mounted() {
    const data = JSON.parse(this.el.dataset.data)
    const keys = Object.keys(data)

    console.log({data})

    this.el.addEventListener('click', () => {
      const d = document.getElementById(this.el.dataset.target)
      if (!d) return

      for (const key of keys) {
        const el = d.querySelector(`[data-ref=${key}]`)
        if (el) {
          if (key == 'asset_name') {
          el.innerText = `${data[key]} (${data['asset_id']})`
          } else if(key == 'id') {
          el.innerText = `${data[key]} (${data['transaction_type']['label']})`
          } else if(key == 'price') {
          el.innerText = `${data[key]} @ ${data['quantity']} shares`
          } else if(key == 'asset_id') {
          el.innerText = `${data['price'] * data['quantity']}`
          } else if(key == 'status') {
          el.innerText = `${data[key]['label']}`
          } else {
          el.innerText = data[key]
          }
        }

        const input = d.querySelector(`[data-input=${key}]`)
        if (input) {
          input.setAttribute('value', data[key])
        }

        const btn = d.querySelector(`[data-click=${key}]`)
        if (btn) {
          const form = document.getElementById(btn.dataset.ref)
          if (form && !data[key]) {
            form.classList.add('flex')
            form.classList.remove('hidden')
          } else if (form) {
            form.classList.add('hidden')
            form.classList.remove('flex')
          }
        }
      }

      d.showModal()
    })

  }
}

export default ModalOpenerHook
