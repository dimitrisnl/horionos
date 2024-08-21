let Hooks = {};

Hooks.AutoHideFlash = {
  mounted() {
    let duration = 4_000;

    setTimeout(() => {
      this.el.style.opacity = 0;
      this.el.style.transition = "opacity 0.2s ease-out";
      setTimeout(() => {
        this.el.remove();
      }, 500);
    }, duration);
  },
};

Hooks.LocalTime = {
  mounted() {
    console.log("foo");
    this.updated();
  },
  updated() {
    let dt = new Date(this.el.textContent);
    this.el.textContent = Intl.DateTimeFormat("default", {
      dateStyle: "medium",
      // timeStyle: "short",
    }).format(dt);
    this.el.classList.remove("invisible");
  },
};

export default Hooks;
