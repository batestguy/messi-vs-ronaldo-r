(() => {
  "use strict";

  const installWave6Polish = () => {
    const main = document.querySelector("main");
    if (main) {
      main.id = "dashboard-main";
      if (!main.hasAttribute("tabindex")) main.setAttribute("tabindex", "-1");
    }

    if (main && !document.getElementById("skip-dashboard-main")) {
      const skipLink = document.createElement("a");
      skipLink.id = "skip-dashboard-main";
      skipLink.className = "skip-link";
      skipLink.href = "#dashboard-main";
      skipLink.textContent = "Skip to dashboard content";
      document.body.insertBefore(skipLink, document.body.firstChild);
    }

    const liveStatus = document.getElementById("app-live-status");
    if (!liveStatus || !window.jQuery) return;

    let busyTimer = null;
    let clearTimer = null;
    let announcedBusy = false;
    const setStatus = (message) => {
      liveStatus.textContent = message;
    };

    window.jQuery(document).off(".wave6");
    window.jQuery(document).on("shiny:busy.wave6", () => {
      if (clearTimer) {
        window.clearTimeout(clearTimer);
        clearTimer = null;
      }
      if (busyTimer) window.clearTimeout(busyTimer);
      announcedBusy = false;
      busyTimer = window.setTimeout(() => {
        setStatus("Updating dashboard…");
        announcedBusy = true;
        busyTimer = null;
      }, 300);
    });

    window.jQuery(document).on("shiny:idle.wave6", () => {
      if (busyTimer) {
        window.clearTimeout(busyTimer);
        busyTimer = null;
      }
      if (!announcedBusy) return;
      setStatus("Dashboard updated.");
      announcedBusy = false;
      clearTimer = window.setTimeout(() => {
        if (liveStatus.textContent === "Dashboard updated.") setStatus("");
        clearTimer = null;
      }, 1200);
    });
  };

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", installWave6Polish, { once: true });
  } else {
    installWave6Polish();
  }
})();
