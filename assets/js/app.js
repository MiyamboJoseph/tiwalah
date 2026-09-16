// If you want to use Phoenix channels, run `mix help phx.gen.channel`
// to get started and then uncomment the line below.
// import "./user_socket.js"

// You can include dependencies in two ways.
//
// The simplest option is to put them in assets/vendor and
// import them using relative paths:
//
//     import "../vendor/some-package.js"
//
// Alternatively, you can `npm install some-package --prefix assets` and import
// them using a path starting with the package name:
//
//     import "some-package"
//
// If you have dependencies that try to import CSS, esbuild will generate a separate `app.css` file.
// To load it, simply add a second `<link>` to your `root.html.heex` file.

// Include phoenix_html to handle method=PUT/DELETE in forms and buttons.
import "phoenix_html"
// Establish Phoenix Socket and LiveView configuration.
import {Socket} from "phoenix"
import {LiveSocket} from "phoenix_live_view"
import {hooks as colocatedHooks} from "phoenix-colocated/app"
import topbar from "../vendor/topbar"

const AudioRecorder = {
  mounted() {
    const recordButton = this.el.querySelector("[data-record]")
    const pauseButton = this.el.querySelector("[data-pause]")
    const stopButton = this.el.querySelector("[data-stop]")
    const status = this.el.querySelector("[data-status]")
    const timer = this.el.querySelector("[data-recording-timer]")
    let recorder
    let chunks = []
    let timerInterval
    let timerStartedAt
    let elapsedMilliseconds = 0
    const report = (stage, details = {}) => {
      console.info("[Tilawah recorder]", stage, details)
    }

    const extensionFor = (mimeType) => {
      const type = mimeType.split(";")[0]

      if (type === "audio/mp4") return "m4a"
      if (type === "audio/ogg") return "ogg"
      if (type === "audio/mpeg") return "mp3"
      if (type === "audio/wav") return "wav"
      return "webm"
    }

    const formatDuration = (milliseconds) => {
      const totalSeconds = Math.floor(milliseconds / 1000)
      const minutes = Math.floor(totalSeconds / 60).toString().padStart(2, "0")
      const seconds = (totalSeconds % 60).toString().padStart(2, "0")

      return `${minutes}:${seconds}`
    }

    const updateTimer = () => {
      if (timer) {
        const activeMilliseconds = timerStartedAt ? Date.now() - timerStartedAt : 0
        timer.textContent = formatDuration(elapsedMilliseconds + activeMilliseconds)
      }
    }

    const startTimer = () => {
      elapsedMilliseconds = 0
      timerStartedAt = Date.now()
      updateTimer()
      timerInterval = window.setInterval(updateTimer, 250)
      this.timerInterval = timerInterval
    }

    const pauseTimer = () => {
      if (timerStartedAt) elapsedMilliseconds += Date.now() - timerStartedAt
      window.clearInterval(timerInterval)
      timerInterval = undefined
      this.timerInterval = undefined
      timerStartedAt = undefined
      updateTimer()
    }

    const resumeTimer = () => {
      timerStartedAt = Date.now()
      updateTimer()
      timerInterval = window.setInterval(updateTimer, 250)
      this.timerInterval = timerInterval
    }

    recordButton.addEventListener("click", async () => {
      try {
        report("microphone_requested")
        this.stream = await navigator.mediaDevices.getUserMedia({audio: true})
        recorder = new MediaRecorder(this.stream)
        report("recorder_started", {mime_type: recorder.mimeType || "browser default"})
        chunks = []
        recorder.addEventListener("dataavailable", event => {
          if (event.data.size > 0) {
            chunks.push(event.data)
            report("audio_chunk_received", {bytes: event.data.size})
          }
        })
        recorder.addEventListener("stop", () => {
          try {
            const mimeType = recorder.mimeType || "audio/webm"
            const audio = new File(
              [new Blob(chunks, {type: mimeType})],
              `recitation.${extensionFor(mimeType)}`,
              {type: mimeType.split(";")[0]},
            )

            report("upload_dispatched", {
              file_name: audio.name,
              file_type: audio.type,
              bytes: audio.size,
              chunk_count: chunks.length,
            })

            const uploadInput = this.el
              .closest("form")
              ?.querySelector("input[type='file'][data-phx-upload-ref]")

            report("upload_input_lookup", {
              found: Boolean(uploadInput),
              input_name: uploadInput?.name || "not found",
              upload_ref: uploadInput?.getAttribute("data-phx-upload-ref") || "not found",
            })

            if (!uploadInput) {
              status.textContent = "The recording input is unavailable. Please refresh and try again."
              return
            }

            uploadInput.dispatchEvent(
              new CustomEvent("track-uploads", {
                bubbles: true,
                detail: {files: [audio]},
              }),
            )
            report("upload_event_dispatched")
            this.stream.getTracks().forEach(track => track.stop())
            pauseTimer()
            pauseButton.disabled = true
            pauseButton.textContent = "Pause recording"
            status.textContent = "Recording attached. Uploading now…"
          } catch (error) {
            console.error("[Tilawah recorder] upload preparation failed", error)
            report("upload_preparation_failed", {message: error.message || "unknown error"})
            status.textContent = "The recording could not be prepared. Please try again."
          }
        })
        recorder.start()
        startTimer()
        recordButton.disabled = true
        pauseButton.disabled = false
        pauseButton.textContent = "Pause recording"
        stopButton.disabled = false
        status.textContent = "Recording in progress…"
      } catch (error) {
        console.error("[Tilawah recorder] microphone unavailable", error)
        report("microphone_unavailable", {message: error.message || "unknown error"})
        status.textContent = "Microphone access was unavailable. Please upload an audio file instead."
      }
    })

    pauseButton.addEventListener("click", () => {
      if (!recorder) return

      if (recorder.state === "recording") {
        recorder.pause()
        pauseTimer()
        pauseButton.textContent = "Resume recording"
        status.textContent = "Recording paused. Resume when you are ready."
      } else if (recorder.state === "paused") {
        recorder.resume()
        resumeTimer()
        pauseButton.textContent = "Pause recording"
        status.textContent = "Recording in progress…"
      }
    })

    stopButton.addEventListener("click", () => {
      if (recorder && recorder.state !== "inactive") {
        report("stop_requested", {state: recorder.state})
        recorder.stop()
      }
      pauseTimer()
      recordButton.disabled = false
      pauseButton.disabled = true
      pauseButton.textContent = "Pause recording"
      stopButton.disabled = true
    })

  },
  destroyed() {
    window.clearInterval(this.timerInterval)
    this.stream?.getTracks().forEach(track => track.stop())
  },
}

const LocationPicker = {
  mounted() {
    const button = this.el.querySelector("[data-use-location]")
    const status = this.el.querySelector("[data-location-status]")
    const latitude = this.el.querySelector("[data-latitude]")
    const longitude = this.el.querySelector("[data-longitude]")

    if (!button || !latitude || !longitude) return

    button.addEventListener("click", () => {
      if (!navigator.geolocation) {
        status.textContent = "Location is unavailable in this browser. You can still use normal reminders."
        return
      }

      button.disabled = true
      status.textContent = "Requesting your location…"

      navigator.geolocation.getCurrentPosition(
        position => {
          // Prayer times do not require a home-level GPS position. Keeping only
          // two decimal places provides a city/neighbourhood approximation.
          latitude.value = position.coords.latitude.toFixed(2)
          longitude.value = position.coords.longitude.toFixed(2)

          ;[latitude, longitude].forEach(input => {
            input.dispatchEvent(new Event("input", {bubbles: true}))
            input.dispatchEvent(new Event("change", {bubbles: true}))
          })

          status.textContent = "Approximate location saved. Due-practice reminders will arrive shortly after Maghrib."
          button.textContent = "Approximate location saved"
        },
        error => {
          const message = error.code === error.PERMISSION_DENIED
            ? "Location permission was not granted. You can continue with normal reminders."
            : "We could not determine your location. You can continue with normal reminders."

          status.textContent = message
          button.disabled = false
        },
        {enableHighAccuracy: false, timeout: 10_000, maximumAge: 86_400_000},
      )
    })
  },
}

const csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")
const liveSocket = new LiveSocket("/live", Socket, {
  longPollFallbackMs: 2500,
  params: {_csrf_token: csrfToken},
  hooks: {...colocatedHooks, AudioRecorder, LocationPicker},
})

// Show progress bar on live navigation and form submits
topbar.config({barColors: {0: "#29d"}, shadowColor: "rgba(0, 0, 0, .3)"})
window.addEventListener("phx:page-loading-start", _info => topbar.show(300))
window.addEventListener("phx:page-loading-stop", _info => topbar.hide())

// connect if there are any LiveViews on the page
liveSocket.connect()

// expose liveSocket on window for web console debug logs and latency simulation:
// >> liveSocket.enableDebug()
// >> liveSocket.enableLatencySim(1000)  // enabled for duration of browser session
// >> liveSocket.disableLatencySim()
window.liveSocket = liveSocket

// The lines below enable quality of life phoenix_live_reload
// development features:
//
//     1. stream server logs to the browser console
//     2. click on elements to jump to their definitions in your code editor
//
if (process.env.NODE_ENV === "development") {
  window.addEventListener("phx:live_reload:attached", ({detail: reloader}) => {
    // Enable server log streaming to client.
    // Disable with reloader.disableServerLogs()
    reloader.enableServerLogs()

    // Open configured PLUG_EDITOR at file:line of the clicked element's HEEx component
    //
    //   * click with "c" key pressed to open at caller location
    //   * click with "d" key pressed to open at function component definition location
    let keyDown
    window.addEventListener("keydown", e => keyDown = e.key)
    window.addEventListener("keyup", _e => keyDown = null)
    window.addEventListener("click", e => {
      if(keyDown === "c"){
        e.preventDefault()
        e.stopImmediatePropagation()
        reloader.openEditorAtCaller(e.target)
      } else if(keyDown === "d"){
        e.preventDefault()
        e.stopImmediatePropagation()
        reloader.openEditorAtDef(e.target)
      }
    }, true)

    window.liveReloader = reloader
  })
}
