// JavaScript entry loaded by importmap ("application" pin).
// Keep this file in app/assets/javascript so Propshaft serves the correct module.
import "@hotwired/turbo-rails"
import "controllers"

// Convert all server-rendered UTC timestamps to the viewer's browser timezone.
const LOCAL_TIME_SELECTOR = "[data-user-local-time='true']"

const pad2 = (value) => String(value).padStart(2, "0")

const browserZoneAbbreviation = (date) => {
  const parts = new Intl.DateTimeFormat(undefined, { timeZoneName: "short" }).formatToParts(date)
  return parts.find((part) => part.type === "timeZoneName")?.value || ""
}

const formatUserLocalTimestamp = (date, includeZone) => {
  const base = `${date.getFullYear()}-${pad2(date.getMonth() + 1)}-${pad2(date.getDate())} ${pad2(date.getHours())}:${pad2(date.getMinutes())}`
  if (!includeZone) return base
  const zone = browserZoneAbbreviation(date)
  return zone ? `${base} ${zone}` : base
}

const renderBrowserLocalTimes = () => {
  document.querySelectorAll(LOCAL_TIME_SELECTOR).forEach((element) => {
    const utcIso = element.dataset.utcIso
    if (!utcIso) return

    const parsed = new Date(utcIso)
    if (Number.isNaN(parsed.getTime())) return

    const includeZone = element.dataset.includeZone === "true"
    element.textContent = formatUserLocalTimestamp(parsed, includeZone)
  })
}

document.addEventListener("turbo:load", renderBrowserLocalTimes)
document.addEventListener("DOMContentLoaded", renderBrowserLocalTimes)
