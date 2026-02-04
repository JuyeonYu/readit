// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails
import "@hotwired/turbo-rails"
import "controllers"

// Smooth scroll only for anchor links (not page navigation)
document.addEventListener("click", (event) => {
  const link = event.target.closest("a[href^='#']")
  if (link) {
    const targetId = link.getAttribute("href").slice(1)
    const target = document.getElementById(targetId)
    if (target) {
      event.preventDefault()
      target.scrollIntoView({ behavior: "smooth" })
    }
  }
})

import "trix"
import "@rails/actiontext"
