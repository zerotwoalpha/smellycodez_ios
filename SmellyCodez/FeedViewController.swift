import UIKit
import Foundation
import Firebase
import GoogleSignIn
import SVProgressHUD

class FeedViewController: UIViewController, UITableViewDelegate, UITableViewDataSource, UINavigationControllerDelegate, UIImagePickerControllerDelegate, GIDSignInUIDelegate {

    @IBOutlet var tableView: UITableView!
    @IBOutlet var signinButtonItem: UIBarButtonItem!
    
    let cellReuseIdentifier = "card"
    
    var items:[DataSnapshot] = []
    
    let imagePicker:UIImagePickerController = UIImagePickerController()
    
    let itemsPerPage:Int = 3
    var currentPage:Int = 0
    var ref:DatabaseQuery? = nil
    
    @IBAction func onSignInButtonClicked(_ sender: UIBarButtonItem) {
        if Auth.auth().currentUser == nil {
            GIDSignIn.sharedInstance().uiDelegate = self
            GIDSignIn.sharedInstance().signIn()
        }
        else {
            try! Auth.auth().signOut()
        }
    }
    
    @IBAction func onButtonClicked(_ sender: UIButton) {
        if Auth.auth().currentUser != nil {
            imagePicker.delegate = self
            imagePicker.sourceType = .photoLibrary
            present(imagePicker, animated: true, completion: nil)
        }
        else {
            let alert = UIAlertController(title: "Must Sign In...", message: "You must sign in before posting a smelly code!", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
            self.present(alert, animated: true, completion: nil)
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        
    }
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : Any]) {
        imagePicker.dismiss(animated: true, completion: nil)

        let image = info[UIImagePickerControllerOriginalImage] as? UIImage
        let resizedImage = resizeImage(image: image!, newWidth: 500)
        let ref:DatabaseReference = Database.database().reference().child("posts")
        let key = ref.child("posts").childByAutoId().key
        
        uploadImage(image: resizedImage, key: key) { (fileUrl) in
            
            let alert = UIAlertController(title: "Type a message...", message: "It's your image caption", preferredStyle: .alert)
            alert.addTextField { (textField) in
                textField.text = ""
            }
            alert.addAction(UIAlertAction(title: "OK", style: .default, handler: { (_) in
                let textField = alert.textFields![0]
                
                ref.child(key).setValue([
                    "userId": Auth.auth().currentUser?.uid ?? "",
                    "label": textField.text ?? "",
                    "picture": fileUrl ?? "",
                    "date": ServerValue.timestamp()
                    ])
                
                Analytics.logEvent("posted", parameters: nil)
                Analytics.setUserProperty("true", forName: "poster")
                
            }))
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
            self.present(alert, animated: true, completion: nil)
        }
        
    }
    
    func uploadImage(image: UIImage, key: String, completion: @escaping (_ url: String?) -> Void) {
        SVProgressHUD.show()
        let storageRef = Storage.storage().reference().child("\(key).png")
        if let uploadData = UIImagePNGRepresentation(image) {
            let metadata = StorageMetadata()
            metadata.contentType = "image/png"
            storageRef.putData(uploadData, metadata: metadata) { (metadata, error) in
                SVProgressHUD.dismiss()
                if error != nil {
                    print("error")
                    completion(nil)
                } else {
                    completion((metadata?.downloadURL()?.absoluteString)!)
                }
            }
        }
    }
    
    func loadItems() {
        
        ref = Database.database().reference().child("posts")
        
        ref!.observe(.value, with: { (snapshot) -> Void in
//            self.items.removeAll()
            for item in snapshot.children.allObjects as! [DataSnapshot] {
                self.items.insert(item, at: 0)
            }
            self.tableView.reloadData()
        })
        
//        ref!.observeSingleEvent(of: .value, with: { (snapshot) in
//            for item in snapshot.children.allObjects as! [DataSnapshot] {
//                self.items.insert(item, at: 0)
//            }
//            self.tableView.reloadData()
//        })

        
//        ref!.observe(.childAdded, with: { (snapshot) -> Void in
//            self.items.insert(snapshot, at: 0)
//            self.tableView.insertRows(at: [IndexPath(row: 0, section: 0)], with: UITableViewRowAnimation.automatic)
//        })

        
        
//        self.currentPage += 1
//        
//        if (ref != nil) {
//            ref!.removeAllObservers()
//        }
        
        
//        ref = Database.database().reference().child("posts").queryOrderedByKey().queryLimited(toLast: UInt(self.currentPage * self.itemsPerPage))        
        
//        ref!.observe(.childAdded, with: { (snapshot) -> Void in
//            if self.items.index(where: { $0.key == snapshot.key }) == nil {
//                self.items.insert(snapshot, at: 0)
//                self.items.sort(by: { $0.key > $1.key})
//                if let index = self.items.index(where: { $0.key == snapshot.key }) {
//                    self.tableView.insertRows(at: [IndexPath(row: index, section: 0)], with: UITableViewRowAnimation.automatic)
//                }
//            }
//        })
        
        ref!.observe(.childChanged, with: {(snapshot) -> Void in
            if let index = self.items.index(where: { $0.key == snapshot.key }) {
                self.items[index] = snapshot
                self.tableView.reloadRows(at: [IndexPath(row: index, section: 0)], with: UITableViewRowAnimation.automatic)
            }
        })
        
        ref!.observe(.childRemoved, with: {(snapshot) -> Void in
            if let index = self.items.index(where: { $0.key == snapshot.key }) {
                self.items.remove(at: index)
                self.tableView.deleteRows(at: [IndexPath(row: index, section: 0)], with: UITableViewRowAnimation.automatic)
            }
        })
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.tableView.rowHeight = UITableViewAutomaticDimension
        self.tableView.estimatedRowHeight = 50 // or something
        
        loadItems()
        
        Auth.auth().addStateDidChangeListener { (auth, user) in
            if (user == nil) {
                self.signinButtonItem.title = "Sign In"
            }
            else {
                self.signinButtonItem.title = "Sign Out"
            }
        }
    }
    
    func resizeImage(image: UIImage, newWidth: CGFloat) -> UIImage {
        let scale = newWidth / image.size.width
        let newHeight = image.size.height * scale
        let size:CGSize = CGSize(width: newWidth, height: newHeight)
        UIGraphicsBeginImageContext(size)
        let rect = CGRect(origin: CGPoint.zero, size: size)
        image.draw(in: rect)
        let newImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return newImage!
    }
    

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.items.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        let cell:FeedCardCell = self.tableView.dequeueReusableCell(withIdentifier: cellReuseIdentifier) as! FeedCardCell

        
        let snapshot:DataSnapshot = self.items[indexPath.row]
        cell.setSnapshot(snapshot: snapshot)
        
//        if (indexPath.row == (currentPage * itemsPerPage) - 1) {
//            loadItems()
//        }
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        print("You tapped cell number \(indexPath.row).")
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }


}

