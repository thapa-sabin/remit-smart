import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this.updateThemeBasedOnPreference()
  }

  toggle() {
    if (document.documentElement.classList.contains("light-mode")) {
      this.enableDarkMode()
    } else {
      this.enableLightMode()
    }
  }

  enableLightMode() {
    document.documentElement.classList.remove("dark-mode")
    document.documentElement.classList.add("light-mode")
    localStorage.setItem("theme", "light")
  }

  enableDarkMode() {
    document.documentElement.classList.remove("light-mode")
    document.documentElement.classList.add("dark-mode")
    localStorage.setItem("theme", "dark")
  }

  updateThemeBasedOnPreference() {
    const savedTheme = localStorage.getItem("theme")
    if (savedTheme === "light") {
      this.enableLightMode()
    } else if (savedTheme === "dark") {
      this.enableDarkMode()
    } else if (window.matchMedia("(prefers-color-scheme: light)").matches) {
      this.enableLightMode()
    } else {
      this.enableDarkMode() // Default to dark mode designed initially
    }
  }
}
