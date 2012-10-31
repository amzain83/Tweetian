import QtQuick 1.1
import com.nokia.meego 1.0
import com.nokia.extras 1.1
import QtMobility.location 1.2
import "twitter.js" as Twitter
import "Services/TwitLonger.js" as TwitLonger
import "Services/Global.js" as G
import "Component"
import Uploader 1.0
import Harmattan 1.0

Page{
    id: newTweetPage

    property string type: "New" //"New","Reply", "RT" or "DM"
    property string tweetId //for "Reply", "RT"
    property string screenName //for "DM"
    property string placedText: ""
    property double latitude: 0
    property double longitude: 0
    property string imageURL: ""

    onStatusChanged: if(status === PageStatus.Activating) preventTouch.enabled = false

    HarmattanMusic{
        id: harmattanMusic
        onMediaReceived: {
            if(mediaName) tweetTextArea.text = "#NowPlaying " + mediaName
            else infoBanner.alert("No music is playing currently or music player is not running.")
        }
    }

    tools: ToolBarLayout{
        parent: newTweetPage
        anchors{ left: parent.left; right: parent.right; margins: constant.graphicSizeLarge }
        enabled: !preventTouch.enabled
        ButtonRow{
            exclusive: false
            spacing: constant.paddingMedium

            ToolButton{
                id: tweetButton
                text: {
                    if(type == "New") return "Tweet"
                    else if(type == "RT") return "Retweet"
                    else return type
                }
                enabled: (tweetTextArea.text.length != 0 || addImageButton.checked)
                         && ((settings.enableTwitLonger && !addImageButton.checked) || !tweetTextArea.errorHighlight)
                         && !header.busy
                onClicked: {
                    if(type == "New" || type == "Reply") {
                        if(addImageButton.checked) imageUploader.run()
                        else {
                            if(tweetTextArea.errorHighlight) script.createUseTwitLongerDialog()
                            else {
                                Twitter.postStatus(tweetTextArea.text, tweetId ,latitude, longitude, script.postStatusOnSuccess, script.commonOnFailure)
                                header.busy = true
                            }
                        }
                    }
                    else if(type == "RT") {
                        Twitter.postRetweet(tweetId, script.postStatusOnSuccess, script.commonOnFailure)
                        header.busy = true
                    }
                    else if(type == "DM") {
                        Twitter.postDirectMsg(tweetTextArea.text, screenName, script.postStatusOnSuccess, script.commonOnFailure)
                        header.busy = true
                    }
                }
            }
            ToolButton{
                id: cancelButton
                text: "Cancel"
                onClicked: pageStack.pop()
            }
        }
    }

    TextArea{
        id: tweetTextArea
        anchors { left: parent.left; top: header.bottom; right: parent.right; margins: constant.paddingMedium }
        readOnly: header.busy
        textFormat: TextEdit.PlainText
        errorHighlight: wordCountText.text < 0 && type != "RT"
        placeholderText: "Tap to write..."
        font.pixelSize: constant.fontSizeXXLarge
        text: placedText
        states: [
            State{
                name: "Fit Keyboard"
                when: inputContext.softwareInputPanelVisible
                AnchorChanges{ target: tweetTextArea; anchors.bottom: parent.bottom }
                PropertyChanges{ target: tweetTextArea; anchors.bottomMargin: autoCompleter.height + 2 * buttonColumn.anchors.margins}
            },
            State{
                name: "Fit Text"
                when: !inputContext.softwareInputPanelVisible
                PropertyChanges{ target: tweetTextArea; height: implicitHeight < 120 ? 120 : undefined}
            }
        ]
        onTextChanged: {
            var lastWord = text.substring(text.lastIndexOf(" ") + 1, cursorPosition)
            autoCompleter.model.clear()
            if(/^(@|#)\w*$/.test(lastWord) && newTweetPage.status === PageStatus.Active){
                inputMethodHints = Qt.ImhNoPredictiveText
                screenNamesMatcher.sendMessage({"word": lastWord, "model": autoCompleter.model,
                                                   "screenNames": cache.screenNames, "hashtags": cache.hashtags})
            }
            else inputMethodHints = Qt.ImhNone
        }

        Text{
            id: wordCountText
            font.pixelSize: constant.fontSizeLarge
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: constant.paddingMedium
            color: constant.colorMid
            text: addImageButton.checked ? 140 - constant.charReservedPerMedia - tweetTextArea.text.length
                                         : 140 - tweetTextArea.text.length
        }
    }

    Loader{ anchors.fill: tweetTextArea; sourceComponent: type == "RT" ? rtCoverComponent : undefined }

    Component{
        id: rtCoverComponent

        Rectangle{
            color: "white"
            opacity: 0.9
            radius: constant.paddingLarge

            Text{
                color: "black"
                anchors.centerIn: parent
                font.pixelSize: tweetTextArea.font.pixelSize * 1.25
                text: "Tap to Edit"
            }

            MouseArea{
                anchors.fill: parent
                enabled: !header.busy
                onClicked: {
                    tweetTextArea.forceActiveFocus()
                    type = "New"
                }
            }
        }
   }

    Column{
        id: buttonColumn
        anchors{ left: parent.left; right: parent.right; top: tweetTextArea.bottom; margins: constant.paddingMedium }
        height: childrenRect.height
        spacing: constant.paddingMedium

        ListView{
            id: autoCompleter
            width: parent.width
            height: constant.graphicSizeMedium
            visible: inputContext.softwareInputPanelVisible
            delegate: ListButton{
                height: ListView.view.height
                text: buttonText
                onClicked: {
                    // FIXME
                    var lastWord = tweetTextArea.text.substring(tweetTextArea.text.lastIndexOf(" ") + 1, tweetTextArea.cursorPosition)
                    tweetTextArea.text = tweetTextArea.text.replace(lastWord, buttonText + " ")
                    tweetTextArea.cursorPosition = tweetTextArea.text.indexOf(buttonText) + buttonText.length + 1
                    tweetTextArea.forceActiveFocus()
                }
            }
            orientation: ListView.Horizontal
            spacing: constant.paddingSmall
            model: ListModel{}
        }

        Row{
            id: newTweetButtonRow
            width: parent.width
            height: childrenRect.height
            spacing: constant.paddingMedium
            visible: type == "New" || type == "Reply"

            Button{
                id: locationButton
                iconSource: settings.invertedTheme ? "Image/add_my_location_inverse.svg" : "Image/add_my_location.svg"
                width: (parent.width - constant.paddingMedium) / 2
                text: "Add"
                enabled: !header.busy
                states: [
                    State {
                        name: "loading"
                        PropertyChanges {
                            target: locationButton
                            text: "Updating..."
                            checked: false
                        }
                    },
                    State {
                        name: "done"
                        PropertyChanges {
                            target: locationButton
                            text: "View/Remove"
                            iconSource: settings.invertedTheme ? "Image/location_mark_inverse.svg"
                                                               : "Image/location_mark.svg"
                            checked: true
                        }
                    }
                ]
                onClicked: {
                    if(state == "done") locationDialog.open()
                    else {
                        positionSource.start()
                        state = "loading"
                    }
                }
            }

            Button{
                id: addImageButton
                iconSource: settings.invertedTheme ? "Image/photos_inverse.svg" : "Image/photos.svg"
                width: (parent.width - constant.paddingMedium) / 2
                text: checked ? "Remove" : "Add"
                enabled: !header.busy
                checked: imageURL != ""
                onClicked: {
                    if(checked) imageURL = ""
                    else pageStack.push(Qt.resolvedUrl("SelectImagePage.qml"), {newTweetPage: newTweetPage})
                }
            }
        }

        SectionHeader{ text: "Quick Tweet"; visible: newTweetButtonRow.visible }

        Button{
            width: parent.width
            visible: newTweetButtonRow.visible
            enabled: !header.busy
            text: "#NowPlaying"
            onClicked: harmattanMusic.requestCurrentMedia()
        }
    }

    PageHeader{
        id: header
        headerIcon: type == "DM" ? "Image/create_message.svg" : "image://theme/icon-m-toolbar-edit-white-selected"
        headerText: {
            if(type == "New") return "New Tweet"
            else if(type == "Reply") return "Reply to " + placedText.substring(0, placedText.indexOf(" "))
            else if(type == "RT") return "Retweet"
            else if(type == "DM") return "DM to @" + screenName
        }
        visible: inPortrait || !inputContext.softwareInputPanelVisible
        height: visible ? undefined : 0
    }

    // This menu can't be dynamically load as it will cause "Segmentation fault" when loading MapPage
    ContextMenu{
        id: locationDialog
        MenuLayout{
            MenuItem{
                text: "View location"
                onClicked: {
                    preventTouch.enabled = true
                    pageStack.push(Qt.resolvedUrl("MapPage.qml"), {"latitude": latitude, "longitude": longitude})
                }
            }
            MenuItem{
                text: "Remove location"
                onClicked: {
                    latitude = 0
                    longitude = 0
                    locationButton.state = ""
                }
            }
        }
    }

    // this is to prevent any interaction in this page when loading the MapPage
    MouseArea{
        id: preventTouch
        anchors.fill: parent
        z: 1
        enabled: false
    }

    WorkerScript{
        id: screenNamesMatcher
        source: "WorkerScript/AutoCompleter.js"
    }

    PositionSource{
        id: positionSource
        updateInterval: 1000

        onPositionChanged: {
            latitude = position.coordinate.latitude
            longitude = position.coordinate.longitude
            positionSource.stop()
            locationButton.state = "done"
        }

        Component.onDestruction: stop()
    }

    ImageUploader{
        id: imageUploader
        service: settings.imageUploadService
        onSuccess: {
            if(service == ImageUploader.Twitter) script.postStatusOnSuccess(JSON.parse(replyData))
            else {
                var imageLink = ""
                if(service == ImageUploader.TwitPic) imageLink = JSON.parse(replyData).url
                else if(service == ImageUploader.MobyPicture) imageLink = JSON.parse(replyData).media.mediaurl
                else if(service == ImageUploader.Imgly) imageLink = JSON.parse(replyData).url
                Twitter.postStatus(tweetTextArea.text+" "+imageLink, tweetId, latitude, longitude,
                                   script.postStatusOnSuccess, script.commonOnFailure)
            }
        }
        onFailure: script.commonOnFailure(status, statusText)
        onProgressChanged: header.headerText = "Uploading..." + progress + "%"

        function run(){
            imageUploader.setFile(imageURL)
            if(service == ImageUploader.Twitter){
                imageUploader.setParameter("status", tweetTextArea.text)
                if(tweetId) imageUploader.setParameter("in_reply_to_status_id", tweetId)
                if(latitude != 0 && longitude != 0){
                    imageUploader.setParameter("lat", latitude.toString())
                    imageUploader.setParameter("long", longitude.toString())
                }
                imageUploader.setAuthorizationHeader(Twitter.getTwitterImageUploadAuthHeader())
            }
            else{
                if(service == ImageUploader.TwitPic) imageUploader.setParameter("key", G.Global.TwitPic.API_KEY)
                else if(service == ImageUploader.MobyPicture) imageUploader.setParameter("key", G.Global.MobyPicture.API_KEY)
                imageUploader.setParameter("message", tweetTextArea.text)
                imageUploader.setAuthorizationHeader(Twitter.getOAuthEchoAuthHeader())
            }
            header.busy = true
            imageUploader.send()
        }
    }

    QtObject{
        id: script

        property string twitLongerId: ""

        function postStatusOnSuccess(data){
            switch(type){
            case "New": infoBanner.alert("Tweet sent."); break;
            case "Reply": infoBanner.alert("Reply sent."); break;
            case "DM":infoBanner.alert("Direct message sent."); break;
            case "RT": infoBanner.alert("Retweet sent."); break;
            }
            pageStack.pop()
        }

        function twitLongerOnSuccess(twitLongerId, shortenTweet){
            script.twitLongerId = twitLongerId
            Twitter.postStatus(shortenTweet, tweetId ,latitude, longitude, postTwitLongerStatusOnSuccess, script.commonOnFailure)
        }

        function postTwitLongerStatusOnSuccess(data){
            TwitLonger.postIDCallback(twitLongerId, data.id_str)
            switch(type){
            case "New": infoBanner.alert("Tweet sent."); break;
            case "Reply": infoBanner.alert("Reply sent."); break;
            }
            pageStack.pop()
        }

        function commonOnFailure(status, statusText){
            if(status === 0) infoBanner.alert("Connection error.")
            else infoBanner.alert("Error: " + status + " " + statusText)
            header.busy = false
        }

        function createUseTwitLongerDialog(){
            var message = "Your tweet is more than 140 characters. Do you want to use TwitLonger to post your tweet?\n\
Note: The tweet content will be publicly visible even your tweet is private."
            dialog.createQueryDialog("Use TwitLonger?", "", message, function(){
                var replyScreenName = placedText ? placedText.substring(1, placedText.indexOf(" ")) : ""
                TwitLonger.postTweet(settings.userScreenName, tweetTextArea.text, tweetId, replyScreenName,
                                     twitLongerOnSuccess, commonOnFailure)
                header.busy = true
            })
        }
    }
}