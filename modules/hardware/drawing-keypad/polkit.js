// Let the desktop user start/stop the Krita keypad (kanata-drawing) without
// a password; the krita wrapper does this on launch and exit.
polkit.addRule(function (action, subject) {
  if (
    action.id == "org.freedesktop.systemd1.manage-units" &&
    action.lookup("unit") == "kanata-drawing.service" &&
    subject.user == "bitcrushing" &&
    subject.local &&
    subject.active
  ) {
    var verb = action.lookup("verb");
    if (verb == "start" || verb == "stop" || verb == "restart") {
      return polkit.Result.YES;
    }
  }
});
