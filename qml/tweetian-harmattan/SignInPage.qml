import QtQuick 1.1
import QtWebKit 1.0
import com.nokia.meego 1.0
import "twitter.js" as Twitter
import "Component"

Page{
    id: signInPage

    property string tokenTempo: ""
    property string tokenSecretTempo: ""

    tools: ToolBarLayout{
        ToolIcon{
            platformIconId: "toolbar-back-dimmed"
            enabled: false
        }
        ToolIcon{
            platformIconId: "toolbar-refresh"
            onClicked: {
                Twitter.postRequestToken(script.requestTokenOnSuccess, script.onFailure)
                header.busy = true
            }
        }
    }

    Component.onCompleted: {
        Twitter.postRequestToken(script.requestTokenOnSuccess, script.onFailure)
        header.busy = true
    }

    onStatusChanged: if(status === PageStatus.Deactivating) settings.settingsLoaded()

    Flickable{
        id: webViewFlickable
        anchors { top: header.bottom; left: parent.left; right: parent.right; bottom: parent.bottom }
        contentHeight: signInWebView.height
        contentWidth: signInWebView.width

        WebView{
            id: signInWebView
            preferredHeight: webViewFlickable.height
            preferredWidth: webViewFlickable.width
            onUrlChanged: {
                var index = (url.toString()).indexOf("oauth_verifier=")
                if(index !== -1){
                    var oauthVerifier = (url.toString()).substring(index + 15, url.length)
                    Twitter.postAccessToken(tokenTempo, tokenSecretTempo, oauthVerifier,
                                            script.accessTokenOnSuccess, script.onFailure)
                    stop.trigger()
                }
            }
            onLoadStarted: header.busy = true
            onLoadFinished: header.busy = false
            onLoadFailed: header.busy = false
        }
    }

    ScrollDecorator{ flickableItem: webViewFlickable }

    PageHeader{
        id: header
        headerText: "Sign In to Twitter"
        headerIcon: "Image/sign_in.svg"
    }

    QtObject{
        id: script

        function requestTokenOnSuccess(token, tokenSecret){
            tokenTempo = token
            tokenSecretTempo = tokenSecret
            signInWebView.url = "https://api.twitter.com/oauth/authorize?oauth_token=" + tokenTempo
        }

        function accessTokenOnSuccess(token, tokenSecret, screenName){
            settings.oauthToken = token
            settings.oauthTokenSecret = tokenSecret
            settings.userScreenName = screenName
            infoBanner.alert("Signed in successfully.")
            pageStack.pop(null)
        }

        function onFailure(status, statusText){
            if(status === 0) infoBanner.alert("Connection error. Click the refresh button to try again.")
            else infoBanner.alert("Error: " + status + " " + statusText + ". Click the refresh button to try again.")
            header.busy = false
        }
    }
}