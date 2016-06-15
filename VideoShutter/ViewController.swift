//
//  ViewController.swift
//  VideoShutter
//
//  Created by SEKINE YURI on 2016/05/25.
//  Copyright © 2016年 SEKINE YURI. All rights reserved.
//

import UIKit
import AVFoundation

class ViewController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate,UIGestureRecognizerDelegate , UIImagePickerControllerDelegate, UINavigationControllerDelegate {//最後2つは表情認識のため追加
    
    var input:AVCaptureDeviceInput!
    var output:AVCaptureVideoDataOutput!
    var session:AVCaptureSession!
    var camera:AVCaptureDevice!
    var imageView:UIImageView!
    
  //  var originalImage: UIImage!
    @IBOutlet var boardimageView: UIImageView!
    

    /** 画像認識 */
    var detector:CIDetector?
    @IBOutlet private weak var outputTextView: UITextView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        //何秒に一回写真を撮る
         NSTimer.scheduledTimerWithTimeInterval(3.0, target: self, selector: #selector(ViewController.takeStillPicture), userInfo: nil, repeats: true)
        //selector:のあと"takeStillPicture"でもいいけど警告になる
        
        
        // 画面タップでシャッターを切るための設定
      /*  let tapGesture:UITapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(ViewController.tapped(_:)))//上同様、"tapped"でもOK
        
        // デリゲートをセット
        tapGesture.delegate = self;
        // Viewに追加.
        self.view.addGestureRecognizer(tapGesture)*/
        

    }
    
    
    override func viewWillAppear(animated: Bool) {
        // スクリーン設定
        setupDisplay()
        // カメラの設定
        setupCamera()
    }
    
    // メモリ解放
    override func viewDidDisappear(animated: Bool) {
        // camera stop メモリ解放
        session.stopRunning()
        
        for output in session.outputs {
            session.removeOutput(output as? AVCaptureOutput)
        }
        
        for input in session.inputs {
            session.removeInput(input as? AVCaptureInput)
        }
        session = nil
        camera = nil
    }
    
    func setupDisplay(){
        //スクリーンの幅
        let screenWidth = UIScreen.mainScreen().bounds.size.width;
        //スクリーンの高さ
        let screenHeight = UIScreen.mainScreen().bounds.size.height;
        
        // プレビュー用のビューを生成
        imageView = UIImageView()
        imageView.frame = CGRectMake(0.0, 0.0, screenWidth, screenHeight)
    }
    
    func setupCamera(){
        // AVCaptureSession: キャプチャに関する入力と出力の管理
        session = AVCaptureSession()
        
        // sessionPreset: キャプチャ・クオリティの設定
        session.sessionPreset = AVCaptureSessionPresetHigh
        //        session.sessionPreset = AVCaptureSessionPresetPhoto
        //        session.sessionPreset = AVCaptureSessionPresetHigh
        //        session.sessionPreset = AVCaptureSessionPresetMedium
        //        session.sessionPreset = AVCaptureSessionPresetLow
        
        // AVCaptureDevice: カメラやマイクなどのデバイスを設定
        for caputureDevice: AnyObject in AVCaptureDevice.devices() {
            // 前面カメラを取得
            if caputureDevice.position == AVCaptureDevicePosition.Front { //背面Front を　Backに
                camera = caputureDevice as? AVCaptureDevice
            }
        }
        
        // カメラからの入力データ
        do {
            input = try AVCaptureDeviceInput(device: camera) as AVCaptureDeviceInput
        } catch let error as NSError {
            print(error)
        }
        
        
        // 入力をセッションに追加
        if(session.canAddInput(input)) {
            session.addInput(input)
        }
        
        // AVCaptureStillImageOutput:静止画
        // AVCaptureMovieFileOutput:動画ファイル
        // AVCaptureVideoDataOutput:動画フレームデータ
        
        // AVCaptureVideoDataOutput:動画フレームデータを出力に設定
        output = AVCaptureVideoDataOutput()
        // 出力をセッションに追加
        if(session.canAddOutput(output)) {
            session.addOutput(output)
        }
        
        // ピクセルフォーマットを 32bit BGR + A とする
        output.videoSettings = [kCVPixelBufferPixelFormatTypeKey : Int(kCVPixelFormatType_32BGRA)]
        
        // フレームをキャプチャするためのサブスレッド用のシリアルキューを用意
        output.setSampleBufferDelegate(self, queue: dispatch_get_main_queue())
        
        output.alwaysDiscardsLateVideoFrames = true
        
        // ビデオ出力に接続
        //        let connection = output.connectionWithMediaType(AVMediaTypeVideo)
        
        session.startRunning()
        
        // deviceをロックして設定
        // swift 2.0
        do {
            try camera.lockForConfiguration()
            // フレームレート
            camera.activeVideoMinFrameDuration = CMTimeMake(1, 30)
            
            camera.unlockForConfiguration()
        } catch _ {
        }
    }
    
    
    // 新しいキャプチャの追加で呼ばれる
    func captureOutput(captureOutput: AVCaptureOutput!, didOutputSampleBuffer sampleBuffer: CMSampleBuffer!, fromConnection connection: AVCaptureConnection!) {
        
        // キャプチャしたsampleBufferからUIImageを作成
        let image:UIImage = self.captureImage(sampleBuffer)
        
        
       // originalImage = self.captureImage(sampleBuffer)//付け足し
        
        // 画像を画面に表示
        dispatch_async(dispatch_get_main_queue()) {
            self.imageView.image = image
            // UIImageViewをビューに追加
            
            //ここを消すとプレビューがなくなるけど撮影はできる!!!!!!!!
            //self.view.addSubview(self.imageView)
        }
    }
    
    // sampleBufferからUIImageを作成
    func captureImage(sampleBuffer:CMSampleBufferRef) -> UIImage{
        
        // Sampling Bufferから画像を取得
        let imageBuffer:CVImageBufferRef = CMSampleBufferGetImageBuffer(sampleBuffer)!
        
        // pixel buffer のベースアドレスをロック
        CVPixelBufferLockBaseAddress(imageBuffer, 0)
        
        let baseAddress:UnsafeMutablePointer<Void> = CVPixelBufferGetBaseAddressOfPlane(imageBuffer, 0)
        
        let bytesPerRow:Int = CVPixelBufferGetBytesPerRow(imageBuffer)
        let width:Int = CVPixelBufferGetWidth(imageBuffer)
        let height:Int = CVPixelBufferGetHeight(imageBuffer)
        
        // 色空間
        let colorSpace:CGColorSpaceRef = CGColorSpaceCreateDeviceRGB()!
        
        let bitsPerCompornent: Int = 8
        // swift 2.0
        let newContext:CGContextRef = CGBitmapContextCreate(baseAddress, width, height, 8, bytesPerRow, colorSpace,  CGImageAlphaInfo.PremultipliedFirst.rawValue|CGBitmapInfo.ByteOrder32Little.rawValue)!
        
        let imageRef:CGImageRef = CGBitmapContextCreateImage(newContext)!
        let resultImage = UIImage(CGImage: imageRef, scale: 1.0, orientation: UIImageOrientation.Right)
        
      //  ImageView.image = info[UIImagePickerControllerEditedImage] as? UIImage

        return resultImage
    }
    
    func takeStillPicture(){
        if var connection:AVCaptureConnection? = output.connectionWithMediaType(AVMediaTypeVideo){
            // アルバムに追加
            UIImageWriteToSavedPhotosAlbum(self.imageView.image!, self, nil, nil)
            
           // self.boardimageView.image = self.imageView.image//映る！！！！
          //  imageView.image = info[UIImagePickerControllerEditedImage] as? UIImage
            detectFaces()
        }
    }
    
    //ここから先表情認識のため追加
    private func detectFaces() {
        
        //let queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)
        
      //  dispatch_async(queue) {
            
            self.boardimageView.image = self.imageView.image

            //self.imageView.image = UIImage(named: "IMG_9757.JPG")//顔認証成功
          //  self.imageView.image = self.originalImage
         //   self.boardimageView.image = self.originalImage
            //self.boardimageView.image = UIImage(named: "IMG_9757.JPG")
        
        
        // create CGImage from image on storyboard.
          guard let image = self.imageView.image, cgImage = image.CGImage else {
                return
            }
            
            let ciImage = CIImage(CGImage: cgImage)
   
        
        
     //   let image = self.imageView.image, cgImage = image!.CGImage
      //  let ciImage = CIImage(CGImage: cgImage!)
        
        
        
        self.boardimageView.image = image
        
        
            // set CIDetectorTypeFace.
            let detector = CIDetector(ofType: CIDetectorTypeFace, context: nil, options: [CIDetectorAccuracy: CIDetectorAccuracyHigh])
            
            // set options
            let options = [CIDetectorSmile : true, CIDetectorEyeBlink : true]
            
            // get features from image
            let features = detector.featuresInImage(ciImage, options: options)
            
            var resultString = "DETECTED FACES:\n\n"
            
          //  self.boardimageView.image = image
            
            for feature in features as! [CIFaceFeature] {
                resultString.appendContentsOf("bounds: \(NSStringFromCGRect(feature.bounds))\n")
                resultString.appendContentsOf("hasSmile: \(feature.hasSmile ? "YES" : "NO")\n")
                resultString.appendContentsOf("faceAngle: \(feature.hasFaceAngle ? String(feature.faceAngle) : "NONE")\n")
                resultString.appendContentsOf("leftEyeClosed: \(feature.leftEyeClosed ? "YES" : "NO")\n")
                resultString.appendContentsOf("rightEyeClosed: \(feature.rightEyeClosed ? "YES" : "NO")\n")
                
                resultString.appendContentsOf("\n")
                
               
                resultString.appendContentsOf("feature中入っているよお")
            }
            resultString.appendContentsOf("aa")
            dispatch_async(dispatch_get_main_queue()) { () -> Void in
                self.outputTextView.text = "\(resultString)"
            }
       // }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }


}

