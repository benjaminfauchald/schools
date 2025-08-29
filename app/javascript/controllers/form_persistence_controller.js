import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["field"]
  static values = { cookieName: String, expireDays: { type: Number, default: 30 } }

  connect() {
    this.loadFormData()
    this.bindEvents()
  }

  disconnect() {
    this.unbindEvents()
  }

  bindEvents() {
    this.fieldTargets.forEach(field => {
      field.addEventListener('input', this.saveFormData.bind(this))
      field.addEventListener('change', this.saveFormData.bind(this))
    })
  }

  unbindEvents() {
    this.fieldTargets.forEach(field => {
      field.removeEventListener('input', this.saveFormData.bind(this))
      field.removeEventListener('change', this.saveFormData.bind(this))
    })
  }

  loadFormData() {
    const savedData = this.getCookie(this.cookieNameValue)
    if (!savedData) return

    try {
      const data = JSON.parse(savedData)
      let fieldsRestored = 0
      
      this.fieldTargets.forEach(field => {
        const fieldName = field.name.split('[').pop().replace(']', '')
        if (data[fieldName] && !field.value) {
          field.value = data[fieldName]
          fieldsRestored++
          
          // Add visual indicator that field was auto-filled
          field.classList.add('bg-blue-50', 'border-blue-300')
          setTimeout(() => {
            field.classList.remove('bg-blue-50', 'border-blue-300')
          }, 3000)
          
          // Trigger input event for any listeners
          field.dispatchEvent(new Event('input', { bubbles: true }))
        }
      })

      if (fieldsRestored > 0) {
        this.showRestoredMessage(fieldsRestored)
      }
    } catch (error) {
      console.error('Failed to parse saved form data:', error)
    }
  }

  saveFormData() {
    const formData = {}
    
    this.fieldTargets.forEach(field => {
      const fieldName = field.name.split('[').pop().replace(']', '')
      if (field.value.trim()) {
        formData[fieldName] = field.value.trim()
      }
    })

    if (Object.keys(formData).length > 0) {
      this.setCookie(this.cookieNameValue, JSON.stringify(formData), this.expireDaysValue)
    }
  }

  clearFormData() {
    this.deleteCookie(this.cookieNameValue)
    
    this.fieldTargets.forEach(field => {
      field.value = ''
    })
    
    this.showClearedMessage()
  }

  showRestoredMessage(count) {
    const message = `Restored ${count} field${count > 1 ? 's' : ''} from previous session`
    this.showToast(message, 'blue')
  }

  showClearedMessage() {
    this.showToast('Saved form data cleared', 'green')
  }

  showToast(message, color = 'blue') {
    // Create toast notification
    const toast = document.createElement('div')
    toast.className = `fixed top-4 right-4 z-50 px-4 py-2 bg-${color}-100 border border-${color}-200 text-${color}-800 text-sm rounded-lg shadow-lg transform transition-all duration-300 translate-x-full opacity-0`
    toast.textContent = message
    
    document.body.appendChild(toast)
    
    // Animate in
    setTimeout(() => {
      toast.classList.remove('translate-x-full', 'opacity-0')
    }, 100)
    
    // Animate out and remove
    setTimeout(() => {
      toast.classList.add('translate-x-full', 'opacity-0')
      setTimeout(() => {
        if (toast.parentNode) {
          toast.parentNode.removeChild(toast)
        }
      }, 300)
    }, 3000)
  }

  getCookie(name) {
    const nameEQ = name + "="
    const ca = document.cookie.split(';')
    
    for (let i = 0; i < ca.length; i++) {
      let c = ca[i]
      while (c.charAt(0) === ' ') c = c.substring(1, c.length)
      if (c.indexOf(nameEQ) === 0) return c.substring(nameEQ.length, c.length)
    }
    
    return null
  }

  setCookie(name, value, days) {
    let expires = ""
    if (days) {
      const date = new Date()
      date.setTime(date.getTime() + (days * 24 * 60 * 60 * 1000))
      expires = "; expires=" + date.toUTCString()
    }
    
    document.cookie = name + "=" + (value || "") + expires + "; path=/; SameSite=Lax"
  }

  deleteCookie(name) {
    document.cookie = name + "=; Path=/; Expires=Thu, 01 Jan 1970 00:00:01 GMT; SameSite=Lax"
  }
}