//
//  ViewController.swift
//  ChatApp
//
//  Created by izumi on 2018/03/14.
//  Copyright © 2018年 example. All rights reserved.
//  http://www.atmarkit.co.jp/ait/articles/1606/06/news020_4.html
//

import UIKit
import JSQMessagesViewController
import Firebase
import FirebaseDatabase
import FirebaseStorage
import Photos
import AVFoundation

// class ViewController: UIViewController {
class ViewController: JSQMessagesViewController, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    var messages = [JSQMessage]()
    let imagePickerController = UIImagePickerController()
    override func viewDidLoad() {
        super.viewDidLoad() //初期状態
        // Do any additional setup after loading the view, typically from a nib.
        //senderDisplayName = "A" //Aさん(自分)の名前
        //senderId = "ID_A"  // AさんのID
        senderDisplayName = "B" //Aさん(自分)の名前
        senderId = "ID_B"  // AさんのID
        // サーバとの連携(firebase)
        let ref = Database.database().reference()   // firebaseの指定root
        // root下の構造(箱)を作る<String, AnyObject>
        ref.observe(.value, with: { DataSnapshot in guard let dic = DataSnapshot.value as? Dictionary<String, AnyObject>
            else{
                return
            }
            // Firebaseのデータを取り出す処理
            // message下のデータを取り扱う(posts=<key,value>)
            // message下の構造(箱)を作る<L7XXX, <ex.disp, ex.A>>
            guard let posts = dic["messages"] as? Dictionary<String, Dictionary<String, AnyObject>> else{
                return
            }
            // taple(key,data)
            var KeyValueArray:[(String, Int)] = []  //[key:String, date:Int]
            // posts: key=L7XXX, value=[disp,date,Id,text]
            for (key, value) in posts{
                if value["date"] != nil{    //nilによるエラーを避ける
                    KeyValueArray.append((key: key, date: Int(value["date"]! as! Int)))
                }
            }
            // dateを基準に並び替える(値が小さいものから大きいものへ：昇順にソート)
            // 0:L7wXXX,1:date
            KeyValueArray.sort{$0.1 < $1.1}
            
            // messagesの再構成
            var preMessages = [JSQMessage]()
            for sortedTuple in KeyValueArray{
                for (key, value) in posts{
                    if key == sortedTuple.0{
                        let senderId = value["senderId"] as! String!
                        let text = value["text"] as! String!
                        let displayName = value["displayName"] as! String!
                        // let time = value["date"] as! Int! % 1000000
                        preMessages.append(JSQMessage(senderId: senderId, displayName: displayName, text: text))
                    }
                }
            }
            
            // 辞書型mapは順番が保証されない, 配列では順番が保証される
            // self.messages = posts.values.map(){ dic in
            // let senderId = dic["senderId"] ?? ""
            // let text = dic["text"] ?? ""
            // let displayName = dic["displayName"] ?? ""
    
            // return JSQMessage(senderId: senderId, displayName: displayName, text: text)
            // }
            self.messages = preMessages
            self.collectionView.reloadData()
            })
        // 自分の名前を表示しない
         self.collectionView!.collectionViewLayout.outgoingAvatarViewSize = CGSize.zero
    }
    
    override func collectionView(_ collectionView: JSQMessagesCollectionView!, messageDataForItemAt indexPath: IndexPath!) -> JSQMessageData! {
        return messages[indexPath.row]
    }
    
    override func collectionView(_ collectionView: JSQMessagesCollectionView!, messageBubbleImageDataForItemAt indexPath: IndexPath!) -> JSQMessageBubbleImageDataSource! {
        if messages[indexPath.row].senderId == senderId{
            return JSQMessagesBubbleImageFactory().outgoingMessagesBubbleImage(with: UIColor(red: 112/255, green:192/255, blue: 75/255, alpha:1));
        }else {
            return JSQMessagesBubbleImageFactory().incomingMessagesBubbleImage(with: UIColor(red: 229/255, green: 229/255, blue: 229/255, alpha: 1))
        }
    }
   
    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = super.collectionView(collectionView, cellForItemAt: indexPath) as? JSQMessagesCollectionViewCell
        if messages[indexPath.row].senderId == senderId{
            cell?.textView?.textColor = UIColor.white
        }else{
            cell?.textView?.textColor = UIColor.darkGray
        }
        return cell!
        }
        
    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection: Int) -> Int{
        return messages.count
    }
    
    // アバター画像の設定
    override func collectionView(_ collectionView: JSQMessagesCollectionView!, avatarImageDataForItemAt indexPath: IndexPath!) -> JSQMessageAvatarImageDataSource! {
        return JSQMessagesAvatarImageFactory.avatarImage(withUserInitials: messages[indexPath.row].senderDisplayName, backgroundColor: UIColor.lightGray, textColor: UIColor.white, font: UIFont.systemFont(ofSize: 10), diameter: 30)
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    // Sendボタンが押された時の動作
    override func didPressSend(_ button: UIButton!, withMessageText text: String!, senderId: String!, senderDisplayName: String!, date: Date!) {
        inputToolbar.contentView.textView.text = ""
        //var ref: DatabaseReference!
        let ref = Database.database().reference()
        // サーバ（Firebase）の子ノードmessagesにデータを保存する
        // senderID, text, displayname, sendingtime(=[".sv":"timestamp"]]
        ref.child("messages").childByAutoId().setValue(["senderId": senderId, "text": text, "displayName": senderDisplayName, "date":[".sv":"timestamp"]])
    }
    
    // ファイル添付のクリップアイコンをタップした場合の処理
    override func didPressAccessoryButton(_ sender: UIButton!) {
        print("select Clip")
        selectImage()   //具体的な処理
    }
    
    private func selectImage(){
        let alertController = UIAlertController(title: "画像選択", message:nil, preferredStyle: .actionSheet)
        let cameraAction = UIAlertAction(title: "カメラ起動", style: .default){
            (UIAlertAction)-> Void in self.selectFromCamera()
        }
        let libraryAction = UIAlertAction(title: "カメラロールから選択", style: .default){
            (UIAlertAction) -> Void in self.selectFromLibrary()
    }
        let cancelAction = UIAlertAction(title: "キャンセル", style: .cancel){
            (UIAlertAction) -> Void in self.dismiss(animated: true, completion: nil)
        }
        
        alertController.addAction(cameraAction)
        alertController.addAction(libraryAction)
        alertController.addAction(cancelAction)
        self.present(alertController, animated: true, completion: nil)
    }
    
    private func selectFromCamera(){
        print("selectFromCamera")
        // カメラの使用可能かチェック
        if UIImagePickerController.isSourceTypeAvailable(.camera) {
            let imagePickerController = UIImagePickerController()
            imagePickerController.delegate = self
            imagePickerController.sourceType = UIImagePickerControllerSourceType.camera
            imagePickerController.cameraCaptureMode = UIImagePickerControllerCameraCaptureMode.photo
            imagePickerController.allowsEditing = true
            self.present(imagePickerController, animated: true, completion: nil)
        } else {
            // カメラを許可していない時の処理
            let cancel = UIAlertAction(title: "OK", style: .cancel){
                (UIAlertAction) -> Void in self.dismiss(animated: true, completion: nil)
            }
            let attention = UIAlertController(title: "このアプリがカメラを利用することを許可してください", message:nil, preferredStyle: .actionSheet)
            attention.addAction(cancel)
            self.present(attention, animated: true, completion: nil)
        }
        
    }
    
    private func selectFromLibrary(){
        print("selectFromLibrary")
        // カメラロールが使用できるようユーザへ促す
        PHPhotoLibrary.requestAuthorization { status in
            switch status {
            case .authorized: print("authorized")
            case .denied: print("denied")
            case .notDetermined: print("NotDetermined")
            case .restricted: print("Restricted")
            }
        }
        // カメラロールを使用可能かチェック
        if UIImagePickerController.isSourceTypeAvailable(UIImagePickerControllerSourceType.photoLibrary) {
            let imagePickerController = UIImagePickerController()
            imagePickerController.delegate = self
            imagePickerController.sourceType = UIImagePickerControllerSourceType.photoLibrary
            imagePickerController.allowsEditing = true
            //以下、思うように動かないため画像反映されない
            //Error Domain=PlugInKit Code=13 "query cancelled" UserInfo={NSLocalizedDescription=query cancelled}
            // アクセス権限がないのに、カメラロールにアクセス可能なため起きるエラー
            // 許可されてもImagePickerControllerは実行されない
            self.present(imagePickerController, animated: true, completion: nil)
        } else {
            // カメラロールを許可していない時の処理
            let cancel = UIAlertAction(title: "OK", style: .cancel){
                (UIAlertAction) -> Void in self.dismiss(animated: true, completion: nil)
            }
            let attention = UIAlertController(title: "このアプリがカメラロールを利用することを許可してください", message:nil, preferredStyle: .actionSheet)
            attention.addAction(cancel)
            self.present(attention, animated: true, completion: nil)
        }
    }
    
    
    private func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String: AnyObject]) {
        print("send?")
        let image = info[UIImagePickerControllerOriginalImage] as! UIImage
        // sendImageMessage(image: image as! UIImage)
        // upload(image: image as! UIImage)
        
        picker.dismiss(animated: true, completion: nil) // Viewへの反映
     }
    
  
    private func sendImageMessage(image: UIImage) {
        print("sendImageMessage")
        let photoItem = JSQPhotoMediaItem(image: image)
        let imageMessage = JSQMessage(senderId: senderId, displayName: senderDisplayName, media: photoItem)
        messages.append(imageMessage!)
        finishSendingMessage(animated: true)
    }
    
    // データベースに画像を保存する
    private func upload(image: UIImage){
        let storage = Storage.storage()
        let storageRef = storage.reference()
        if let data = UIImagePNGRepresentation(image){
            let reference = storageRef.child("images/" + "1" + ".png")
            reference.putData(data, metadata:nil, completion: { metadata, error in
                print(metadata as Any)
                print(error as Any)
            })
            dismiss(animated: true, completion: nil)
            }
        }
}


