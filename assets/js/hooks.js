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

export default Hooks;
