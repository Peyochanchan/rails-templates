import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="clock"
export default class extends Controller {
  static targets = ["second", "min", "hour"]
  static values = { refreshInterval: Number }

  connect() {
    this.startRefreshing()
  }

  startRefreshing() {
    setInterval(() => {
      this.load()
    }, this.refreshIntervalValue)
  }

  load() {
    this.setDate()
  }

  setDate() {
    const now = new Date();
    const seconds = now.getSeconds();
    const secondsDegrees = ((seconds / 60) * 360) + 90;
    this.secondTarget.style.transform = `rotate(${secondsDegrees}deg)`

    const mins = now.getMinutes();
    const minsDegrees = ((mins / 60) * 360) + ((seconds/60)*6) + 90;
    this.minTarget.style.transform = `rotate(${minsDegrees}deg)`;

    const hour = now.getHours();
    const hourDegrees = ((hour / 12) * 360) + ((mins/60)*30) + 90;
    this.hourTarget.style.transform = `rotate(${hourDegrees}deg)`;
  }
}
