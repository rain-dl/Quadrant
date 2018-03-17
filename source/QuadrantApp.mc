using Toybox.Application as App;
using Toybox.WatchUi as Ui;

class QuadrantApp extends App.AppBase {

    private var _quadrantView;

    function initialize() {
        AppBase.initialize();
    }

    // onStart() is called on application start up
    function onStart(state) {
    }

    // onStop() is called when your application is exiting
    function onStop(state) {
    }

    // Return the initial view of your application here
    function getInitialView() {
        _quadrantView = new QuadrantView();
        return [ _quadrantView ];
    }

    // New app settings have been received so trigger a UI update
    function onSettingsChanged() {
        _quadrantView.loadSettings();
        Ui.requestUpdate();
    }
}