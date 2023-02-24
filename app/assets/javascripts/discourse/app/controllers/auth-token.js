import Modal from "discourse/controllers/modal";
import { ajax } from "discourse/lib/ajax";
import { action } from "@ember/object";
import { next } from "@ember/runloop";
import { userPath } from "discourse/lib/url";

export default Modal.extend({
  expanded: false,

  onShow() {
    ajax(
      userPath(`${this.get("currentUser.username_lower")}/activity.json`)
    ).then((posts) => {
      if (posts.length > 0) {
        this.set("latest_post", posts[0]);
        // slightly hacky, but default d-modal focus gets reset
        document.querySelector(".d-modal .modal-close")?.focus();
      }
    });
  },

  @action
  toggleExpanded(event) {
    event?.preventDefault();
    this.set("expanded", !this.expanded);
  },

  actions: {
    highlightSecure() {
      this.send("closeModal");

      next(() => {
        const $prefPasswordDiv = $(".pref-password");

        $prefPasswordDiv.addClass("highlighted");
        $prefPasswordDiv.on("animationend", () =>
          $prefPasswordDiv.removeClass("highlighted")
        );

        window.scrollTo({
          top: $prefPasswordDiv.offset().top,
          behavior: "smooth",
        });
      });
    },
  },
});
