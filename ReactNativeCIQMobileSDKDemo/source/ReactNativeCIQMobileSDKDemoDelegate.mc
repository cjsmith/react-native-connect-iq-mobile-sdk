import Toybox.Lang;
import Toybox.WatchUi;

class ReactNativeCIQMobileSDKDemoDelegate extends WatchUi.BehaviorDelegate {

    function initialize() {
        BehaviorDelegate.initialize();
    }

    function onMenu() as Boolean {
        WatchUi.pushView(new Rez.Menus.MainMenu(), new ReactNativeCIQMobileSDKDemoMenuDelegate(), WatchUi.SLIDE_UP);
        return true;
    }

}