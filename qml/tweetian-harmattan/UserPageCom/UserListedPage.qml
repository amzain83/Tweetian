import QtQuick 1.1
import com.nokia.meego 1.0
import "../Delegate"
import "../twitter.js" as Twitter

AbstractUserPage{
    id: userListedPage

    property string nextCursor: ""

    headerText: "Listed"
    headerNumber: userInfoData.listedCount
    emptyText: "No list"
    loadMoreButtonVisible: listView.count > 0 && listView.count % 20 === 0
    delegate: ListDelegate{}

    onReload: {
        if(reloadType === "all") nextCursor = ""
        Twitter.getUserListsMemberships(userInfoData.screenName, nextCursor, function(data){
            for(var i=0; i<data.lists.length; i++){
                var obj = {
                    "listName": data.lists[i].name,
                    "subscriberCount": data.lists[i].subscriber_count,
                    "listId": data.lists[i].id_str,
                    "memberCount": data.lists[i].member_count,
                    "listDescription": data.lists[i].description,
                    "ownerUserName": data.lists[i].user.name,
                    "ownerScreenName": data.lists[i].user.screen_name,
                    "profileImageUrl": data.lists[i].user.profile_image_url,
                    "protectedList": data.lists[i].mode === "private",
                    "following": data.lists[i].following
                }
                listView.model.append(obj)
            }
            nextCursor = data.next_cursor_str
            loadingRect.visible = false
        }, function(status, statusText){
            if(status === 0) infoBanner.alert("Connection error.")
            else infoBanner.alert("Error: " + status + " " + statusText)
            loadingRect.visible = false
        })
        loadingRect.visible = true
    }
}