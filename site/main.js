// WallLoop site behaviour. Small and dependency-free; animates only transform and opacity
// (through CSS custom properties) and does nothing that moves under prefers-reduced-motion.
(() => {
  "use strict";

  /** The latest release's DMG. Every [data-download] link points here; change it in one place. */
  const DOWNLOAD_URL = "https://github.com/johnbosco-j/WallLoop/releases/latest/download/WallLoop.dmg";
  for (const link of document.querySelectorAll("[data-download]")) link.href = DOWNLOAD_URL;

  const root = document.documentElement;
  const reduceMotion = matchMedia("(prefers-reduced-motion: reduce)");
  const finePointer = matchMedia("(pointer: fine)");
  const smallScreen = matchMedia("(max-width: 767px)");
  const clamp = (value, min, max) => Math.min(max, Math.max(min, value));

  const nav = document.querySelector(".nav");
  const cta = document.querySelector(".nav__cta");
  const navLinks = [...document.querySelectorAll(".nav__links a")];
  const sections = navLinks.map((a) => document.querySelector(a.getAttribute("href")));
  const hero = document.getElementById("top");
  const heroMark = document.querySelector(".hero__mark");
  const heroCta = document.querySelector(".hero__actions .btn--primary");
  const downloadPanel = document.getElementById("download");
  const innerParallax = [...document.querySelectorAll("[data-parallax-inner]")];

  // ── Orbit: centre the rings on Loopy ─────────────────────────────────
  function centreOrbit() {
    if (!hero || !heroMark) return;
    const heroBox = hero.getBoundingClientRect();
    const markBox = heroMark.getBoundingClientRect();
    hero.style.setProperty("--orbit-y", `${markBox.top - heroBox.top + markBox.height / 2}px`);
  }

  // ── Scroll-linked state ──────────────────────────────────────────────
  let scrollQueued = false;
  function onScroll() {
    // Animation frames pause in background tabs; update directly so state never goes stale.
    if (document.hidden) return updateScroll();
    if (scrollQueued) return;
    scrollQueued = true;
    requestAnimationFrame(updateScroll);
  }

  function updateScroll() {
    scrollQueued = false;
    const vh = innerHeight;
    const middle = vh * 0.5;
    const maxScroll = root.scrollHeight - vh;
    nav.style.setProperty("--progress", maxScroll > 0 ? clamp(scrollY / maxScroll, 0, 1).toFixed(4) : "0");

    // Highlight the section under the middle of the viewport.
    let current = -1;
    sections.forEach((section, i) => {
      if (!section) return;
      const box = section.getBoundingClientRect();
      if (box.top <= middle && box.bottom > middle) current = i;
    });
    navLinks.forEach((a, i) => (i === current ? a.setAttribute("aria-current", "true") : a.removeAttribute("aria-current")));

    // One accent fill per viewport: the nav button fills only after the hero's own
    // Download button has left, and steps back while the download panel is on screen.
    const heroGone = !heroCta || heroCta.getBoundingClientRect().bottom < 72;
    const panel = downloadPanel.getBoundingClientRect();
    const panelVisible = panel.top < vh && panel.bottom > 0;
    cta.classList.toggle("is-filled", heroGone && !panelVisible);

    if (reduceMotion.matches) return;

    // Hero: 0 → 1 as it scrolls away; CSS turns this into the ring tilt and fades.
    const heroBox = hero.getBoundingClientRect();
    hero.style.setProperty("--p", clamp(-heroBox.top / heroBox.height, 0, 1).toFixed(4));

    // App mock: the wallpaper inside the screen drifts with scroll, at most 40px (20px on phones).
    const limit = smallScreen.matches ? 20 : 40;
    for (const el of innerParallax) {
      const box = el.getBoundingClientRect();
      if (box.bottom < 0 || box.top > vh) continue;
      const offset = box.top + box.height / 2 - middle;
      el.style.setProperty("--inner", `${clamp(-offset * 0.08, -limit, limit).toFixed(1)}px`);
    }
  }

  // ── Pointer: the ring plane leans toward the cursor (laptops only) ──
  let target = { x: 0, y: 0 };
  let current = { x: 0, y: 0 };
  let leaning = false;
  function lean() {
    current.x += (target.x - current.x) * 0.08;
    current.y += (target.y - current.y) * 0.08;
    hero.style.setProperty("--yaw", `${(current.x * 10).toFixed(2)}deg`);
    hero.style.setProperty("--pitch", `${(current.y * -8).toFixed(2)}deg`);
    if (Math.abs(target.x - current.x) + Math.abs(target.y - current.y) > 0.001) {
      requestAnimationFrame(lean);
    } else {
      leaning = false;
    }
  }
  addEventListener("pointermove", (event) => {
    if (reduceMotion.matches || !finePointer.matches) return;
    target = { x: event.clientX / innerWidth - 0.5, y: event.clientY / innerHeight - 0.5 };
    if (!leaning) {
      leaning = true;
      requestAnimationFrame(lean);
    }
  }, { passive: true });

  // ── Card spotlight: a soft accent light follows the pointer ─────────
  document.addEventListener("pointermove", (event) => {
    const card = event.target instanceof Element ? event.target.closest(".card") : null;
    if (!card) return;
    const box = card.getBoundingClientRect();
    card.style.setProperty("--mx", `${event.clientX - box.left}px`);
    card.style.setProperty("--my", `${event.clientY - box.top}px`);
  }, { passive: true });

  // ── Mobile menu ──────────────────────────────────────────────────────
  const menuButton = document.querySelector(".nav__menu");
  const sheet = document.getElementById("menu-sheet");
  function setMenu(open) {
    sheet.hidden = !open;
    menuButton.setAttribute("aria-expanded", String(open));
    menuButton.setAttribute("aria-label", open ? "Close menu" : "Open menu");
    menuButton.querySelector("use").setAttribute("href", open ? "#i-close" : "#i-menu");
    document.body.style.overflow = open ? "hidden" : "";
    if (open) sheet.querySelector("a")?.focus();
  }
  menuButton.addEventListener("click", () => setMenu(sheet.hidden));
  sheet.addEventListener("click", (event) => {
    if (event.target instanceof Element && event.target.closest("a")) setMenu(false);
  });
  addEventListener("keydown", (event) => {
    if (event.key === "Escape" && !sheet.hidden) {
      setMenu(false);
      menuButton.focus();
    }
  });
  matchMedia("(min-width: 820px)").addEventListener("change", (event) => event.matches && setMenu(false));

  // ── Start ────────────────────────────────────────────────────────────
  addEventListener("scroll", onScroll, { passive: true });
  addEventListener("resize", () => {
    centreOrbit();
    onScroll();
  }, { passive: true });
  reduceMotion.addEventListener("change", () => {
    hero.style.removeProperty("--p");
    hero.style.removeProperty("--yaw");
    hero.style.removeProperty("--pitch");
    onScroll();
  });
  document.addEventListener("visibilitychange", () => {
    scrollQueued = false;
    updateScroll();
  });
  heroMark?.addEventListener("load", centreOrbit);
  document.fonts?.ready.then(centreOrbit);
  centreOrbit();
  updateScroll();
})();
