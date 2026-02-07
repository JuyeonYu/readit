import { Controller } from "@hotwired/stimulus"

/**
 * Password Toggle Controller
 *
 * Handles showing/hiding the password field based on checkbox state.
 *
 * Usage:
 * <div data-controller="password-toggle">
 *   <input type="checkbox" data-password-toggle-target="checkbox" data-action="change->password-toggle#toggle">
 *   <div data-password-toggle-target="field" class="hidden">
 *     <input type="password" ...>
 *   </div>
 * </div>
 */
export default class extends Controller {
  static targets = ["checkbox", "field"]

  connect() {
    // Set initial state based on checkbox
    if (this.hasCheckboxTarget && this.hasFieldTarget) {
      this.toggle()
    }
  }

  toggle() {
    if (!this.hasFieldTarget) return

    if (this.hasCheckboxTarget && this.checkboxTarget.checked) {
      this.fieldTarget.classList.remove("hidden")
    } else {
      this.fieldTarget.classList.add("hidden")
      // Clear password field when hiding
      const input = this.fieldTarget.querySelector("input")
      if (input) {
        input.value = ""
      }
    }
  }
}
