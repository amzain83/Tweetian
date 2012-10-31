import QtQuick 1.1
import com.nokia.symbian 1.1
import "../Delegate"
import "../twitter.js" as Twitter
import "../storage.js" as Database

AbstractUserPage{
    id: userFollowingPage

    property variant userIdsData

    // The user ids array for the current request, for sending into WorkerScript to sort the user in this array
    // order. Will be set to undefined once used to free memory.
    property variant currentRequestUserIds

    headerText: "Followers"
    headerNumber: userInfoData.followersCount
    emptyText: "No follower"
    loadMoreButtonVisible: listView.count > 0 && listView.count % 50 === 0
    delegate: UserDelegate{}

    onReload: {
        if(reloadType === "all"){
            listView.model.clear()
            Twitter.getFollowersId(userInfoData.screenName, function(data){
                userIdsData = data
                reloadType = "older"
                reload()
            }, __failureCallback)
            loadingRect.visible = true
        }
        else{
            var userCount = Math.min(50, userIdsData.ids.length - listView.count)
            currentRequestUserIds = userIdsData.ids.slice(listView.count, listView.count + userCount)
            if(currentRequestUserIds.length > 0) {
                Twitter.getUserLookup(currentRequestUserIds.join(), function(data){
                backButtonEnabled = false
                userFollowingParser.sendMessage({model: listView.model, data: data,
                    reloadType: reloadType, userIds: currentRequestUserIds})
                }, __failureCallback)
                loadingRect.visible = true
            }
            else {
                infoBanner.alert("Error: No user to load!")
                loadingRect.visible = false
            }
        }
    }

    WorkerScript{
        id: userFollowingParser
        source: "../WorkerScript/UserParser.js"
        onMessage: {
            backButtonEnabled = true
            if(userInfoData.screenName === settings.userScreenName)
                cache.screenNames = Database.storeScreenNames(messageObject.screenNames)
            currentRequestUserIds = undefined
            loadingRect.visible = false
        }
    }

    function __failureCallback(status, statusText){
        if(status === 0) infoBanner.alert("Connection error.")
        else infoBanner.alert("Error: " + status + " " + statusText)
        loadingRect.visible = false
    }
}