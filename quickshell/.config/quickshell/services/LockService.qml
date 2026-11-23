pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Services.Pam

// Session lock: PAM authentication (started at lock, so face unlock runs
// first), the password being typed (shared by the lock surfaces of every
// monitor), locking before the system sleeps and on loginctl lock-session
Singleton {
    id: root

    // ========================================================================
    // PROPERTIES
    // ========================================================================

    property bool locked: false
    // The compositor confirmed the lock (set by LockScreen)
    property bool secure: false
    property bool authenticating: false
    property bool failed: false
    property string failMessage: ""
    property int attempts: 0

    // Monitor showing the password field (the others show the clock)
    property string screen: ""
    // Password being typed; every lock surface edits this one
    property string buffer: ""
    property bool capsLock: false

    readonly property string style: StateService.get("lock.style", "center")
    readonly property bool showStatus: StateService.get("lock.showStatus", true)
    readonly property bool showPower: StateService.get("lock.showPower", true)
    readonly property bool showMedia: StateService.get("lock.showMedia", true)
    readonly property bool lockBeforeSleep: StateService.get("lock.beforeSleep", true)

    // PAM service in /etc/pam.d (lock.pamService, e.g. "hyprlock" for a
    // stack with Howdy's face unlock first); "login" when unset or missing
    readonly property string _requestedService: StateService.get("lock.pamService", "login")
    property bool _requestedExists: false
    readonly property string pamService: _requestedService !== "" && !_requestedService.includes("/") && _requestedExists ? _requestedService : "login"

    // What PAM says while it isn't asking for anything (Howdy's "Attempting
    // face recognition"...), for the lock's status line
    readonly property string pamStatus: pam.active && !pam.responseRequired && !pam.messageIsError ? pam.message : ""

    // A module that needs no password (Howdy's face scan) is running, or
    // about to: from the start of a transaction until PAM asks for the
    // password or finishes. Howdy with detection_notice off says nothing
    // meanwhile, so pamStatus alone can't tell
    readonly property bool scanning: _pamScanning || restartTimer.running
    property bool _pamScanning: false

    signal authSucceeded
    // The password field was clicked: the surfaces take the keyboard back
    signal focusRequested

    // ========================================================================
    // PAM AUTHENTICATION
    // ========================================================================
    // A transaction starts as soon as the screen locks, without a password,
    // so modules that need none (Howdy) run first. A password entered before
    // PAM asks for one waits in _pendingPassword and is sent when it does.
    // After a failure (and on wake, the camera doesn't survive sleep) the
    // transaction starts again, once per event

    property string _pendingPassword: ""
    // PAM asked and nothing was sent yet
    property bool _awaitingResponse: false
    // A password was sent in the running transaction
    property bool _responded: false
    // Restarts in a row with no password involved (a stack failing at once
    // would otherwise loop)
    property int _autoRestarts: 0
    property string _lastError: ""
    // Succeeded: nothing starts again while the lock fades out
    property bool _authed: false

    PamContext {
        id: pam
        config: "login"
        user: Quickshell.env("USER")

        // Every message, also a second prompt in a row (responseRequired
        // doesn't change then)
        onPamMessage: {
            if (pam.messageIsError && pam.message !== "")
                root._lastError = pam.message;
            if (!pam.responseRequired)
                return;
            root._pamScanning = false;
            root._awaitingResponse = true;
            if (root._pendingPassword !== "")
                root._respond();
            else
                root.authenticating = false;
        }

        // Followed by completed(Error)
        onError: error => {
            console.log("[Lock] PAM error:", PamError.toString(error));
            root._lastError = I18n.tr("Authentication error");
        }

        // The conversation is already gone here (message is empty again)
        onCompleted: result => {
            const responded = root._responded;
            root._pamScanning = false;
            root._awaitingResponse = false;
            root._responded = false;
            if (!root.locked || root._authed)
                return;

            if (result === PamResult.Success) {
                console.log("[Lock] Authentication successful");
                root.authenticating = false;
                root._pendingPassword = "";
                root.failed = false;
                root.failMessage = "";
                root._authed = true;
                root.authSucceeded();
                return;
            }

            console.log("[Lock] Authentication failed:", PamResult.toString(result));
            const message = root._lastError !== "" ? root._lastError : I18n.tr("Wrong password");
            root._lastError = "";
            if (responded) {
                // A wrong password: told, and PAM starts over (face first)
                root.authenticating = false;
                root.attempts++;
                root.failMessage = message;
                root.failed = true;
                // This restart is the failure's one
                root._autoRestarts = 1;
                root._restartSoon();
            } else if (root._autoRestarts === 0) {
                // Ended before any password (a face-only stack, an error):
                // once more, keeping a password typed meanwhile
                root._autoRestarts++;
                root._restartSoon();
            } else {
                // Again: stop until the next Enter or wake
                root.authenticating = false;
                root._pendingPassword = "";
                root.failMessage = message;
                root.failed = true;
            }
        }
    }

    function _respond() {
        const password = _pendingPassword;
        _pendingPassword = "";
        _awaitingResponse = false;
        _responded = true;
        // A face scan's complaint isn't the password's
        _lastError = "";
        authenticating = true;
        pam.respond(password);
    }

    function _startPam() {
        restartTimer.stop();
        if (!locked || _authed || pam.active)
            return;
        _awaitingResponse = false;
        _responded = false;
        _lastError = "";
        pam.config = pamService;
        console.log("[Lock] Starting PAM (" + pam.config + ")");
        _pamScanning = true;
        if (!pam.start()) {
            _pamScanning = false;
            // Not startable (config file gone...): no transaction, so no
            // completed() either
            authenticating = false;
            _pendingPassword = "";
            failMessage = I18n.tr("Authentication error");
            failed = true;
        }
    }

    function _restartSoon() {
        restartTimer.restart();
    }

    // Lets the old PAM helper (and the camera) go before the next one
    Timer {
        id: restartTimer
        interval: 500
        onTriggered: root._startPam()
    }

    // Checked once per name (PamContext would only log an error)
    Process {
        id: serviceCheck
        onExited: code => root._requestedExists = code === 0
    }

    function _checkService() {
        _requestedExists = false;
        if (_requestedService !== "" && _requestedService !== "login" && !_requestedService.includes("/")) {
            serviceCheck.command = ["test", "-f", "/etc/pam.d/" + _requestedService];
            serviceCheck.running = true;
        }
    }

    on_RequestedServiceChanged: _checkService()
    Component.onCompleted: _checkService()

    // ========================================================================
    // PUBLIC FUNCTIONS
    // ========================================================================

    function lock() {
        if (!locked) {
            console.log("[Lock] Locking screen");
            screen = Hyprland.focusedMonitor?.name ?? "";
            buffer = "";
            attempts = 0;
            failed = false;
            failMessage = "";
            authenticating = false;
            _pendingPassword = "";
            _autoRestarts = 0;
            _authed = false;
            locked = true;
            checkCapsLock();
            _startPam();
        }
    }

    function unlock() {
        if (locked) {
            console.log("[Lock] Unlocking screen");
            // Only set locked = false here. Do NOT reset failed/failMessage/etc
            // because that triggers signals on the LockScreen which is being
            // destroyed (causes "invalid context" warning). State is reset in lock().
            locked = false;
            secure = false;
            restartTimer.stop();
            pam.abort();
            _pamScanning = false;
            _pendingPassword = "";
        }
    }

    // Called by LockScreen right after it releases the session lock: the
    // service (and the Loader holding the lock) follow on the next turns of
    // the event loop, once the surfaces are destroyed (avoids "invalid
    // context" warnings)
    function unlockSoon() {
        unlockTimer.restart();
    }

    Timer {
        id: unlockTimer
        interval: 50
        onTriggered: root.unlock()
    }

    // Enter: sent now if PAM is asking, else kept until it asks
    function tryUnlock() {
        if (!locked || _authed || authenticating || buffer === "")
            return;
        console.log("[Lock] Attempting authentication");
        _pendingPassword = buffer;
        buffer = "";
        authenticating = true;
        failed = false;
        _autoRestarts = 0;
        if (!pam.active)
            _startPam();
        else if (_awaitingResponse)
            _respond();
    }

    // The face button: PAM again from the top, so a module that needs no
    // password (Howdy) scans once more. Ignored while a scan or a password
    // check runs
    function scanFace() {
        if (!locked || _authed || authenticating || _pendingPassword !== "" || scanning)
            return;
        console.log("[Lock] Face scan requested");
        failed = false;
        _autoRestarts = 0;
        if (pam.active) {
            // Waiting at the password prompt: same restart as on wake
            pam.abort();
            _awaitingResponse = false;
            _restartSoon();
        } else {
            _startPam();
        }
    }

    // A check asked for while one runs reruns after it (Process does)
    function checkCapsLock() {
        capsProc.running = true;
    }

    Process {
        id: capsProc
        command: ["sh", "-c", "hyprctl devices -j | jq '[.keyboards[].capsLock] | any'"]
        stdout: StdioCollector {
            onStreamFinished: root.capsLock = text.trim() === "true"
        }
    }

    // ========================================================================
    // LOCK BEFORE SLEEP
    // ========================================================================

    // A logind "delay" inhibitor holds suspend (lid close included) for up to
    // InhibitDelayMaxSec after PrepareForSleep(true); it is released once the
    // lock is secure, and taken again on wake (PrepareForSleep comes from
    // Login1Service). setpriv --pdeathsig ends the helper with the shell
    // (killed, it was left running as an orphan)
    property bool _holdSleep: lockBeforeSleep

    Process {
        running: root._holdSleep
        command: ["setpriv", "--pdeathsig", "TERM", "--", "systemd-inhibit", "--what=sleep", "--mode=delay", "--who=Quickshell", "--why=Lock the screen before sleeping", "sleep", "infinity"]
    }

    Connections {
        target: Login1Service
        enabled: root.lockBeforeSleep

        function onPrepareForSleep(start: bool): void {
            if (start) {
                root.lock();
                if (root.secure)
                    root._holdSleep = false;
                else
                    releaseFallback.restart();
            } else {
                releaseFallback.stop();
                root._holdSleep = root.lockBeforeSleep;
            }
        }
    }

    // On wake a face scan started before sleeping has a dead camera: start
    // it again, unless a password is waiting for it or being checked
    Connections {
        target: Login1Service

        function onPrepareForSleep(start: bool): void {
            if (start || !root.locked || root._authed || root._responded || root._pendingPassword !== "")
                return;
            console.log("[Lock] Woke up locked: restarting PAM");
            root._autoRestarts = 0;
            pam.abort();
            root._awaitingResponse = false;
            root._restartSoon();
        }

        // loginctl lock-session. Unlock (loginctl unlock-session) is
        // ignored: only PAM unlocks
        function onLockRequested(): void {
            root.lock();
        }
    }

    onSecureChanged: {
        if (secure && releaseFallback.running) {
            releaseFallback.stop();
            _holdSleep = false;
        }
    }

    onLockBeforeSleepChanged: _holdSleep = lockBeforeSleep

    // Never hold the system awake if the lock surface doesn't come up
    Timer {
        id: releaseFallback
        interval: 2000
        onTriggered: root._holdSleep = false
    }

    // ========================================================================
    // IPC — qs ipc call lock lock
    // ========================================================================

    IpcHandler {
        target: "lock"

        function lock(): void {
            root.lock();
        }
    }
}
