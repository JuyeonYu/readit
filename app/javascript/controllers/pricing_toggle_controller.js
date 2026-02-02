import { Controller } from "@hotwired/stimulus"

/**
 * Pricing Toggle Controller
 *
 * Handles the monthly/yearly pricing toggle with smooth transitions.
 *
 * Usage:
 * <div data-controller="pricing-toggle">
 *   <button data-pricing-toggle-target="monthlyBtn" data-action="click->pricing-toggle#selectMonthly">Monthly</button>
 *   <button data-pricing-toggle-target="yearlyBtn" data-action="click->pricing-toggle#selectYearly">Yearly</button>
 *
 *   <span data-pricing-toggle-target="price" data-monthly="12" data-yearly="10">$12</span>
 *   <span data-pricing-toggle-target="monthlyNote">Billed monthly</span>
 *   <span data-pricing-toggle-target="yearlyNote" class="hidden">$120/year</span>
 * </div>
 */
export default class extends Controller {
  static targets = [
    "monthlyBtn",
    "yearlyBtn",
    "price",
    "monthlyNote",
    "yearlyNote"
  ]

  static classes = ["active", "hidden"]
  static values = {
    billing: { type: String, default: "monthly" }
  }

  connect() {
    // Set initial state based on value
    if (this.billingValue === "yearly") {
      this.selectYearly()
    } else {
      this.selectMonthly()
    }
  }

  selectMonthly() {
    this.billingValue = "monthly"
    this.updateUI()
  }

  selectYearly() {
    this.billingValue = "yearly"
    this.updateUI()
  }

  toggle() {
    if (this.billingValue === "monthly") {
      this.selectYearly()
    } else {
      this.selectMonthly()
    }
  }

  updateUI() {
    const isYearly = this.billingValue === "yearly"

    // Update button states
    if (this.hasMonthlyBtnTarget && this.hasYearlyBtnTarget) {
      this.updateButtonState(this.monthlyBtnTarget, !isYearly)
      this.updateButtonState(this.yearlyBtnTarget, isYearly)
    }

    // Update prices with animation
    if (this.hasPriceTarget) {
      this.priceTargets.forEach(priceEl => {
        const monthlyPrice = priceEl.dataset.monthly
        const yearlyPrice = priceEl.dataset.yearly

        if (monthlyPrice && yearlyPrice) {
          this.animatePrice(priceEl, isYearly ? yearlyPrice : monthlyPrice)
        }
      })
    }

    // Toggle billing notes visibility
    if (this.hasMonthlyNoteTarget) {
      this.monthlyNoteTargets.forEach(el => {
        this.toggleVisibility(el, !isYearly)
      })
    }

    if (this.hasYearlyNoteTarget) {
      this.yearlyNoteTargets.forEach(el => {
        this.toggleVisibility(el, isYearly)
      })
    }

    // Dispatch custom event for other components to listen to
    this.dispatch("change", {
      detail: { billing: this.billingValue, isYearly }
    })
  }

  updateButtonState(button, isActive) {
    const activeClasses = ["bg-primary-600", "text-white", "shadow-sm"]
    const inactiveClasses = ["text-gray-600", "hover:text-gray-900"]

    if (isActive) {
      button.classList.remove(...inactiveClasses)
      button.classList.add(...activeClasses)
      button.setAttribute("aria-pressed", "true")
    } else {
      button.classList.remove(...activeClasses)
      button.classList.add(...inactiveClasses)
      button.setAttribute("aria-pressed", "false")
    }
  }

  animatePrice(element, newPrice) {
    // Add transition class
    element.style.transition = "opacity 150ms ease-out, transform 150ms ease-out"
    element.style.opacity = "0"
    element.style.transform = "translateY(-4px)"

    setTimeout(() => {
      element.textContent = `$${newPrice}`
      element.style.opacity = "1"
      element.style.transform = "translateY(0)"
    }, 150)
  }

  toggleVisibility(element, show) {
    if (show) {
      element.classList.remove("hidden", "opacity-0")
      element.classList.add("opacity-100")
    } else {
      element.classList.add("hidden", "opacity-0")
      element.classList.remove("opacity-100")
    }
  }
}
