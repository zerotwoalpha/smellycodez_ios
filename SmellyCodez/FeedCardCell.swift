import UIKit
import Firebase
import Alamofire
import AlamofireImage


class FeedCardCell: UITableViewCell {
    @IBOutlet weak var view: UIView!
    @IBOutlet weak var label: UILabel!
    @IBOutlet weak var picture: UIImageView!
    
    @IBOutlet weak var date: UILabel!
    
    @IBOutlet weak var profileName: UILabel!
    @IBOutlet weak var profilePicture: UIImageView!
    
    @IBOutlet weak var ohShit: UIButton!
    @IBOutlet weak var ohShitCount: UILabel!
    
    var snapshot:DataSnapshot? = nil
    
    var ohShitted:Bool = false

    @IBAction func onOhShitClicked(_ sender: UIButton) {
        if let currentUser = Auth.auth().currentUser, let snapshot = self.snapshot {
            if (self.ohShitted) {
                Analytics.logEvent("unohshitted", parameters: nil)
                Database.database().reference().child("ohshits").child(currentUser.uid).child(snapshot.key).runTransactionBlock({ (currentData) -> TransactionResult in
                    let currentValue = currentData.value as? Bool ?? false
                    if (currentValue) {
                        Database.database().reference().child("posts").child(snapshot.key).child("ohShitsCount").runTransactionBlock({ (currentData) -> TransactionResult in
                            currentData.value = (currentData.value as? Int ?? 0) - 1
                            return TransactionResult.success(withValue: currentData)
                        })
                        currentData.value = false
                    }
                    return TransactionResult.success(withValue: currentData)
                })
            }
            else {
                Analytics.logEvent("ohshitted", parameters: nil)
                Database.database().reference().child("ohshits").child(currentUser.uid).child(snapshot.key).runTransactionBlock({ (currentData) -> TransactionResult in
                    let currentValue = currentData.value as? Bool ?? false
                    if (!currentValue) {
                        Database.database().reference().child("posts").child(snapshot.key).child("ohShitsCount").runTransactionBlock({ (currentData) -> TransactionResult in
                            currentData.value = (currentData.value as? Int ?? 0) + 1
                            return TransactionResult.success(withValue: currentData)
                        })
                        currentData.value = true
                    }
                    return TransactionResult.success(withValue: currentData)
                })
            }
        }
        else {
            let alert = UIAlertController(title: "Must Sign In...", message: "You must sign in before ohshiting a smelly code!", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
            UIApplication.shared.keyWindow?.rootViewController?.present(alert, animated: true, completion: nil)
        }
    }
    
    
    override func prepareForReuse() {
        self.label.text = ""
        self.date.text = ""
        self.profileName.text = ""
        self.profilePicture.image = nil
        self.picture.image = nil
        self.ohShit.setImage(#imageLiteral(resourceName: "ohshit-off"), for: .normal)
        self.ohShitCount.text = ""
        self.ohShitted = false
    }
    
    func setSnapshot(snapshot: DataSnapshot) {
        self.snapshot = snapshot
        self.label.text = snapshot.childSnapshot(forPath: "label").value as? String ?? ""
        self.date.text = "\(NSDate(timeIntervalSince1970: (snapshot.childSnapshot(forPath: "date").value as? TimeInterval ?? 0) / 1000))"
        self.ohShitCount.text = "\(snapshot.childSnapshot(forPath: "ohShitsCount").value as? Int ?? 0)"
        
        if let url:String = snapshot.childSnapshot(forPath: "picture").value as? String {
            let urlRequest = URL(string:  url)
            self.picture.af_setImage(withURL: urlRequest!)
        }
        
        let userId:String = snapshot.childSnapshot(forPath: "userId").value as? String ?? ""
        
        Database.database().reference().child("users").child(userId).observe(.value, with: { (userSnapshot) in
            self.profileName.text = userSnapshot.childSnapshot(forPath: "displayName").value as? String ?? ""
            if let url:String = userSnapshot.childSnapshot(forPath: "photoURL").value as? String {
                let urlRequest = URL(string:  url)
                self.profilePicture.af_setImage(withURL: urlRequest!)
            }
        })
        
        if let currentUser = Auth.auth().currentUser {
            Database.database().reference().child("ohshits").child(currentUser.uid).child(snapshot.key).observe(.value, with: { (ohShitSnapshot) in
                if (ohShitSnapshot.exists() && ohShitSnapshot.value as! Bool) {
                    self.ohShitted = true
                    self.ohShit.setImage(#imageLiteral(resourceName: "ohshit-on"), for: .normal)
                }
                else {
                    self.ohShitted = false
                    self.ohShit.setImage(#imageLiteral(resourceName: "ohshit-off"), for: .normal)
                }
            })
        }
    }
    
}
