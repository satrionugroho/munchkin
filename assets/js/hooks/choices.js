import Choices from "../../vendor/choices.min"

function defineURL(url, ref) {
  if (url && url !== '') {
    const u = new URL(`${document.location.origin}${url}`)
    if (ref && ref !== '') {
      const v = document.querySelector(`[name=${ref}][checked]`)
      if (v) u.searchParams.append(ref, v.value)
    }

    return u
  }
  return undefined
}

let choice

function initializeChoice(el) {
  const nt = el.dataset.noResult || 'No results found'
  const nf = el.dataset.notFound || 'No choices to choose from'
  const nc = el.dataset.noChoice || 'No choices to choose from'
  const pc = el.dataset.placeholder

  const u = defineURL(el.dataset.url, el.dataset.ref)
  const c = new Choices(el, {
    noResultsText: nt,
    noChoicesText: nf,
    noChoicesText: nc,
    searchPlaceholderValue: pc,
    classNames: {
      containerInner: ['!bg-base-100', 'choices__inner', '!border-neutral'],
      listDropdown: ['choices__list--dropdown', '!bg-base-100', '!border-neutral'],
      input: ['choices__input', '!bg-base-100', '!border-neutral'],
      selectedState: ['is-selected', '!bg-base-200']
    }
  })

  c.passedElement.element.addEventListener('search', async evt => {
    if (evt.detail.value.length > 2 && u)  {
      try {
        u.searchParams.append('q', evt.detail.value)
        const resp = await fetch(u.toString())
        const json = await resp.json()

        if (json.status == 200) {
          c.clearStore()
          c.setValue(json.data)
        } else {
          c.clearStore()
        }
      } catch (err) {
        console.log({err})
      }
    }
    console.log({evt})
  })

  return c
}

const ChoicesHook = {
  mounted() {
    choice = initializeChoice(this.el)
  },
  updated() {
    console.log('choices update', {el: this.el, choice})
    choice = initializeChoice(this.el)
    choice.init()
  }
}

export default ChoicesHook
