//
//  SleepTimeViewController.swift
//  SwiftRadio
//
//  Created by Muhammad Imran on 23/06/2020.
//  Copyright © 2020 matthewfecher.com. All rights reserved.
//

import UIKit
import MBCircularProgressBar
class SleepTimeViewController: UIViewController,UITextFieldDelegate {

    @IBOutlet weak var timerLbl: UILabel!
    @IBOutlet weak var stop: UIButton!
    @IBOutlet weak var start: UIButton!
    @IBOutlet weak var textfieldfortime: UITextField!
    @IBOutlet weak var bacjgroundImage: UIImageView!
    let radioPlayer = RadioPlayer()
    @IBOutlet weak var timerProgress: MBCircularProgressBarView!
    var timeLeft = 0
    var timer:Timer?
    @IBOutlet weak var TextField: UITextField!
    override func viewDidLoad() {
        super.viewDidLoad()
        if Constants.HoldingSomeValue != 0{
            //timerLbl.text =  String(Constants.HoldingSomeValue / 60)
            start.isHidden = true
            stop.isHidden = false
            UIView.animate(withDuration: 60) {
                self.timerProgress.value = CGFloat(Constants.HoldingSomeValue / 30)
            }
        }
        }
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(true)
        Constants.HoldingSomeValue = timeLeft
        NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillHideNotification, object: nil)
    }
        
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(true)
        let tap = UITapGestureRecognizer(target: self, action: #selector(taped))
        bacjgroundImage.addGestureRecognizer(tap)
        NotificationCenter.default.addObserver(self, selector: #selector(KeyboardWillShow), name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(KeyboardWillHide), name: UIResponder.keyboardWillHideNotification, object: nil)
        self.timerProgress.value = 0
        timerProgress.layer.cornerRadius = 10
        timerProgress.layer.shadowColor = UIColor(ciColor: .gray).cgColor
        timerProgress.layer.shadowRadius = 10
        
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
    //This Method Will Hide The Keyboard
    @objc func taped(){
     textfieldfortime.resignFirstResponder()
      self.view.endEditing(true)
    }

    @objc func KeyboardWillShow(sender: NSNotification){

        let keyboardSize : CGSize = ((sender.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue.size)!
        if self.view.frame.origin.y == 0{
            self.view.frame.origin.y -= keyboardSize.height
        }

    }

    @objc func KeyboardWillHide(sender : NSNotification){

        let keyboardSize : CGSize = ((sender.userInfo?[UIResponder.keyboardFrameBeginUserInfoKey] as? NSValue)?.cgRectValue.size)!
        if self.view.frame.origin.y != 0{
            self.view.frame.origin.y += keyboardSize.height
        }

    }

    @IBAction func startTimer(_ sender: UIButton) {
        start.isHidden  = true
        stop.isHidden = false
        if textfieldfortime.text != "" {
        textfieldfortime.endEditing(true)
        timeLeft = Int(textfieldfortime.text!)! * 60
        print(timeLeft)
         timer = Timer.scheduledTimer(timeInterval: 1.0, target: self, selector: #selector(fire), userInfo: nil, repeats: true)
        }
        UIView.animate(withDuration: 120) {
                             self.timerProgress.value = CGFloat(self.timeLeft / 30)
             }

    }
    @IBAction func stopimer(_ sender: UIButton) {
        start.isHidden = false
        stop.isHidden = true
        timer?.invalidate()
    }
    
    @objc func fire()
    {
        timerLbl.text =  String(timeLeft / 60)
        timeLeft -= 1
        if timeLeft <= 0 {
            stop.isHidden = true
            start.isHidden = false
            timer?.invalidate()
            radioPlayer.player.stop()
            timer = nil
            print("stop")
        }
    }
           
    
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        let inverseSet = NSCharacterSet(charactersIn:"0123456789").inverted

        let components = string.components(separatedBy: inverseSet)

        let filtered = components.joined(separator: "")

        if filtered == string {
            return true
        } else {
            if string == "." {
                let countdots = textField.text!.components(separatedBy:".").count - 1
                if countdots == 0 {
                    return true
                }else{
                    if countdots > 0 && string == "." {
                        return false
                    } else {
                        return true
                    }
                }
            }else{
                return false
            }
        }
    }

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */

}
