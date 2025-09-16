import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["container", "range", "minThumb", "maxThumb", "display"]
  static values = { 
    minValue: Number,
    maxValue: Number,
    currency: String 
  }

  connect() {
    console.log("🎯 [DUAL SLIDER] Controller connected")
    
    // Setup values
    this.min = 50000
    this.max = 2000000
    this.currentMin = this.minValueValue || 50000
    this.currentMax = this.maxValueValue || 500000
    
    // Find form inputs
    this.minInput = document.querySelector('input[name="school[min_annual_fee]"]')
    this.maxInput = document.querySelector('input[name="school[max_annual_fee]"]')
    
    // Setup dragging
    this.isDragging = false
    this.activeThumb = null
    
    // Initialize positions
    this.updateSlider()
    this.updateDisplay()
    this.updateFormInputs()
    
    // Add event listeners
    this.setupEventListeners()
  }
  
  setupEventListeners() {
    // Mouse events for thumbs
    this.minThumbTarget.addEventListener('mousedown', (e) => this.startDrag(e, 'min'))
    this.maxThumbTarget.addEventListener('mousedown', (e) => this.startDrag(e, 'max'))
    
    // Click on track to move nearest thumb
    this.containerTarget.addEventListener('click', (e) => this.handleTrackClick(e))
  }
  
  startDrag(event, thumbType) {
    event.preventDefault()
    console.log(`🎯 [DUAL SLIDER] Starting drag: ${thumbType}`)
    
    this.isDragging = true
    this.activeThumb = thumbType
    
    document.addEventListener('mousemove', this.handleMouseMove.bind(this))
    document.addEventListener('mouseup', this.stopDrag.bind(this))
  }
  
  handleMouseMove(event) {
    if (!this.isDragging) return
    
    const containerRect = this.containerTarget.getBoundingClientRect()
    const containerWidth = containerRect.width
    const offsetX = event.clientX - containerRect.left
    
    // Convert to percentage
    let percentage = Math.max(0, Math.min(100, (offsetX / containerWidth) * 100))
    
    // Convert to value
    let value = Math.round((percentage / 100) * (this.max - this.min) + this.min)
    
    // Snap to step
    value = Math.round(value / 10000) * 10000
    
    // Apply constraints
    if (this.activeThumb === 'min') {
      value = Math.max(this.min, Math.min(value, this.currentMax - 50000))
      this.currentMin = value
    } else {
      value = Math.max(this.currentMin + 50000, Math.min(value, this.max))
      this.currentMax = value
    }
    
    this.updateSlider()
    this.updateDisplay()
    this.updateFormInputs()
  }
  
  stopDrag() {
    this.isDragging = false
    this.activeThumb = null
    document.removeEventListener('mousemove', this.handleMouseMove.bind(this))
    document.removeEventListener('mouseup', this.stopDrag.bind(this))
  }
  
  handleTrackClick(event) {
    if (this.isDragging) return
    
    const containerRect = this.containerTarget.getBoundingClientRect()
    const containerWidth = containerRect.width
    const offsetX = event.clientX - containerRect.left
    const percentage = (offsetX / containerWidth) * 100
    
    // Determine which thumb is closer
    const minPercentage = ((this.currentMin - this.min) / (this.max - this.min)) * 100
    const maxPercentage = ((this.currentMax - this.min) / (this.max - this.min)) * 100
    
    const distanceToMin = Math.abs(percentage - minPercentage)
    const distanceToMax = Math.abs(percentage - maxPercentage)
    
    // Move the closer thumb
    const thumbType = distanceToMin < distanceToMax ? 'min' : 'max'
    this.activeThumb = thumbType
    this.handleMouseMove(event)
    this.activeThumb = null
  }
  
  updateSlider() {
    const minPercentage = ((this.currentMin - this.min) / (this.max - this.min)) * 100
    const maxPercentage = ((this.currentMax - this.min) / (this.max - this.min)) * 100
    
    // Update thumb positions
    this.minThumbTarget.style.left = `${minPercentage}%`
    this.maxThumbTarget.style.left = `${maxPercentage}%`
    
    // Update range bar
    this.rangeTarget.style.left = `${minPercentage}%`
    this.rangeTarget.style.width = `${maxPercentage - minPercentage}%`
    
    console.log(`🎯 [DUAL SLIDER] Updated: ${this.currentMin} - ${this.currentMax}`)
  }
  
  updateDisplay() {
    const currency = this.currencyValue || 'THB'
    const symbol = currency === 'THB' ? '฿' : currency
    
    const minFormatted = this.currentMin.toLocaleString()
    const maxFormatted = this.currentMax.toLocaleString()
    
    this.displayTarget.textContent = `${minFormatted} - ${maxFormatted} ${symbol}`
  }
  
  updateFormInputs() {
    if (this.minInput) this.minInput.value = this.currentMin
    if (this.maxInput) this.maxInput.value = this.currentMax
  }
}