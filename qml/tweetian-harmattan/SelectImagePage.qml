import QtQuick 1.1
import com.nokia.meego 1.0
import QtMobility.gallery 1.1
import "Component"

Page{
    id: selectImagePage

    property Item newTweetPage: null

    tools: ToolBarLayout{
        ToolIcon{
            platformIconId: "toolbar-back"
            onClicked: pageStack.pop()
        }
        ToolButton{
            text: "Service"
            onClicked: chooseServiceDialogComponent.createObject(selectImagePage)
        }
        Item{ width: 80; height: 64 }
    }

    ContextMenu{
        id: imageMenu

        property string selectedImageURL: ""
        property string selectedImagePath: ""

        MenuLayout{
            MenuItem{
                text: "Select image"
                onClicked: {
                    newTweetPage.imageURL = imageMenu.selectedImagePath
                    pageStack.pop()
                }
            }
            MenuItem{
                text: "Preview"
                onClicked: Qt.openUrlExternally(imageMenu.selectedImageURL)
            }
        }
    }

    GridView{
        id: galleryGridView
        anchors { top: header.bottom; left: parent.left; right: parent.right; bottom: parent.bottom }
        cellWidth: inPortrait ? width / 3 : (width / 5 - constant.paddingSmall)
        cellHeight: cellWidth
        delegate: imageDelegate
        model: galleryModel.ready ? galleryModel : undefined
    }

    Text{
        anchors.centerIn: parent
        font.pixelSize: constant.fontSizeXXLarge
        color: constant.colorMid
        text: "No image"
        visible: galleryModel.ready && galleryModel.count == 0
    }

    ScrollDecorator{ flickableItem: galleryModel.ready ? galleryGridView : null }

    PageHeader{
        id: header
        headerText: "Select Image"
        headerIcon: "Image/photos.svg"
        onClicked: galleryGridView.positionViewAtBeginning()
    }

    DocumentGalleryModel{
        id: galleryModel

        property bool ready: status === DocumentGalleryModel.Idle || status === DocumentGalleryModel.Finished

        autoUpdate: true
        properties: ["filePath", "url"]
        sortProperties: ["-lastModified"]
        rootType: DocumentGallery.Image
        onStatusChanged: {
            if(status === DocumentGalleryModel.Active) header.busy = true
            else if(status === DocumentGalleryModel.Error){
                header.busy = false
                infoBanner.alert("Error loading image from gallery")
            }
            else header.busy = false
        }
    }

    Component{
        id: imageDelegate
        Item{
            width: GridView.view.cellWidth
            height: width
            scale: mouseArea.pressed ? 0.9 : 1.0

            Behavior on scale { NumberAnimation{ duration: 100 } }

            Image{
                id: image
                asynchronous: true
                source: url
                sourceSize.width: width
                anchors.fill: parent
                fillMode: Image.PreserveAspectCrop
                clip: true
                cache: false
            }

            Loader{
                id: iconLoader
                anchors.centerIn: parent
                sourceComponent: {
                    switch(image.status){
                    case Image.Null:
                    case Image.Error:
                        return icon
                    case Image.Loading:
                        return busy
                    case Image.Ready:
                        return undefined
                    }
                }

                Component{
                    id: icon

                    Image{
                        sourceSize.width: constant.graphicSizeMedium
                        sourceSize.height: constant.graphicSizeMedium
                        source: settings.invertedTheme ? "Image/photos_inverse.svg" : "Image/photos.svg"
                    }
                }

                Component{
                    id: busy

                    BusyIndicator{
                        width: constant.graphicSizeMedium
                        height: constant.graphicSizeMedium
                        running: true
                    }
                }
            }

            MouseArea{
                id: mouseArea
                anchors.fill: parent
                onClicked: {
                    imageMenu.selectedImageURL = url
                    imageMenu.selectedImagePath = filePath
                    imageMenu.open()
                }
            }
        }
    }

    Component{
        id: chooseServiceDialogComponent

        SelectionDialog{
            id: chooseServiceDialog
            property bool __isClosing: false
            titleText: "Image Upload Service"
            model: ListModel{
                ListElement{ name: "Twitter"}
                ListElement{ name: "TwitPic"}
                ListElement{ name: "MobyPicture"}
                ListElement{ name: "img.ly"}
            }
            selectedIndex: settings.imageUploadService
            onSelectedIndexChanged: settings.imageUploadService = selectedIndex
            Component.onCompleted: open()
            onStatusChanged: {
                if(status === DialogStatus.Closing) __isClosing = true
                else if(status === DialogStatus.Closed && __isClosing) chooseServiceDialog.destroy(250)
            }
        }
    }
}