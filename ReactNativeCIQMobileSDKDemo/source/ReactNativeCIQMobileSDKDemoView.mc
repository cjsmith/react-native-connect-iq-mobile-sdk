import Toybox.Graphics;
import Toybox.WatchUi;
import Toybox.Communications;


class ReactNativeCIQMobileSDKDemoView extends WatchUi.View {
    (:background)
    class ConnectionListenerImpl extends Communications.ConnectionListener {
        function initialize() {
            Communications.ConnectionListener.initialize();
        }
        function onComplete() {
            System.println("Transmit Complete");
        }

        function onError() {
            System.println("Transmit Failed");
        }
    }

    function onTransmitComplete(isSuccess) {
        if (isSuccess) {
            System.println("Message sent successfully.");
        } else {
            System.println("Message failed to send.");
        }
    }

    function phoneMessageCallback(msg as Communications.PhoneAppMessage) {
        System.println("Received message " + msg.data);
        var message = "received " + msg.data + "; hello from Connect IQ";
        Communications.transmit(message, null, new ConnectionListenerImpl());
    }

    function initialize() {
        View.initialize();
        var phoneCallback = method(:phoneMessageCallback) as Communications.PhoneMessageCallback; 
        // set up somewhere to store the message
        // set up phoneMessageCallback
        // register the messages from the callback to capture the results
        Communications.registerForPhoneAppMessages(phoneCallback);
    }

    // Load your resources here
    function onLayout(dc as Dc) as Void {
        setLayout(Rez.Layouts.MainLayout(dc));
    }

    // Called when this View is brought to the foreground. Restore
    // the state of this View and prepare it to be shown. This includes
    // loading resources into memory.
    function onShow() as Void {
    }

    // Update the view
    function onUpdate(dc as Dc) as Void {
        // Call the parent onUpdate function to redraw the layout
        View.onUpdate(dc);
    }

    // Called when this View is removed from the screen. Save the
    // state of this View here. This includes freeing resources from
    // memory.
    function onHide() as Void {
    }

}
