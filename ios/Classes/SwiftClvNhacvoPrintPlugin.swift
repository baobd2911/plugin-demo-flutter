import Flutter
import UIKit
import CoreBluetooth
import Foundation



@available(iOS 10.0, *)
extension SwiftClvNhacvoPrintPlugin: CBCentralManagerDelegate,CBPeripheralDelegate ,CBPeripheralManagerDelegate{
    
    public func centralManagerDidUpdateState(_ central: CBCentralManager) {
        bluetoothState = central.state
        switch central.state {
        case .unknown:
            print("central.state is .unknown")
        case .resetting:
            print("central.state is .resetting")
        case .unsupported:
            print("central.state is .unsupported")
        case .unauthorized:
            print("central.state is .unauthorized")
        case .poweredOff:
            print("central.state is .poweredOff")
        case .poweredOn:
            print("central.state is .poweredOn")
        }
    }
    
    public func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        switch peripheral.state {
        case .poweredOn:
            print("Peripheral Is Powered On.")
        case .unsupported:
            print("Peripheral Is Unsupported.")
        case .unauthorized:
            print("Peripheral Is Unauthorized.")
        case .unknown:
            print("Peripheral Unknown")
        case .resetting:
            print("Peripheral Resetting")
        case .poweredOff:
            print("Peripheral Is Powered Off.")
        @unknown default:
            print("Error")
        }
    }
    
    public func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        print("Discovered \(peripheral.name ?? "unknown") : \(peripheral.identifier.uuidString)")
        channel.invokeMethod("action_new_device", arguments: toMap(peripheral))
    }
    
    
    private func toMap(_ device: CBPeripheral) -> [String:String] {
        arrayPeripehral.append(device)
        return ["name": device.name ?? device.identifier.uuidString, "address": device.identifier.uuidString]
    }
    
    public func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        print("Connected!")
        checkIsConnect = true
        peripheral.delegate = self
        peripheral.discoverServices(nil)
        channel.invokeMethod("action_connected", arguments: checkIsConnect)
    }
        
    
    public func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if ((error) != nil) {
            print("Error discovering services: \(error!.localizedDescription)")
            return
        }
        guard let services = peripheral.services else {
            return
        }
        
        for service in services {
            peripheral.discoverCharacteristics(nil, for: service)
        }
        print("Discovered Services: \(services)")
    }
    
    public func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        if let characteristics = service.characteristics {
            for characteristic in characteristics {
                if characteristic.uuid == CBUUID(string: "BEF8D6C9-9C21-4C9E-B632-BD58C1009F9F") {
                    writablePeripheral = peripheral
                    writablecharacteristic = service.characteristics?.filter { $0.uuid.uuidString == writablecharacteristicUUID }.first
                    peripheral.setNotifyValue(true, for: characteristic)
                    peripheral.readValue(for: characteristic)

                }
            }
        }
    }
    
    
    public func disconnectAllPrinter() {
        centralManager.retrieveConnectedPeripherals(withServices: [CBUUID(string: "E7810A71-73AE-499D-8C15-FAA9AEF0C3F2")]).forEach {
            centralManager.cancelPeripheralConnection($0)
        }
    }
}

@available(iOS 10.0, *)
public class SwiftClvNhacvoPrintPlugin: NSObject, FlutterPlugin, CBPeripheralDelegate,CBCentralManagerDelegate {
    var centralManager: CBCentralManager! = CBCentralManager(delegate: nil, queue: nil,
                                                             options: ["CBCentralManagerOptionShowPowerAlertKey" : 0])
    var bluetoothState: CBManagerState = .unknown
    let channel: FlutterMethodChannel
    var scanTimer: Timer?
    var listCropImage: [UIImage] = []
    var textString: String?
    var arrayPeripehral = [CBPeripheral]()
    var checkIsConnect: Bool = false
    var wellDoneCanWriteData: ((CBPeripheral) -> ())?
    private let writablecharacteristicUUID = "BEF8D6C9-9C21-4C9E-B632-BD58C1009F9F"
    var writablePeripheral: CBPeripheral?
    var writablecharacteristic: CBCharacteristic?
    {
        didSet {
            if let wc = writablecharacteristic, let wp = writablePeripheral {
                wp.setNotifyValue(true, for: wc)
                wellDoneCanWriteData?(wp)
            }
        }
    }
    
    
    private(set) var peripheral: CBPeripheral?
    
    
    init(_ channel: FlutterMethodChannel) {
        self.channel = channel
        super.init()
        centralManager.delegate = self
    }
    
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "flutter_scan_bluetooth", binaryMessenger: registrar.messenger())
        let instance = SwiftClvNhacvoPrintPlugin(channel)
        registrar.addMethodCallDelegate(instance, channel: channel)
        print("instance \(instance)")
    }
    
    
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult)   {
        switch call.method {
        case "scanDevice":
            scanDevice(call:call,result: result)
            break;
        case "action_stop_scan":
            action_stop_scan(call:call,result: result)
            break;
        case "state":
            state(call:call,result: result)
            break
        case "connectDevice":
            connectDevice(call:call,result: result)
            break;
        case "action_request_permissions":
            action_request_permissions(call:call,result: result)
            break;
        case "remove_all_device":
            if(centralManager.isScanning) {
                disconnectAllPrinter()
                stopScan()
            }

            break;
        case "onPrint":
            onPrint(call:call,result: result)
            break
        default:
            result(FlutterMethodNotImplemented);
        }
    }
    
    public func printImage(listImage: UIImage){
        guard let p = writablePeripheral, let c = writablecharacteristic else {
            return
        }
        let receipt = Receipt(.init(maxWidthDensity: 384, fontDesity: 12, encoding: .utf8))
        <<< Image(listImage.cgImage!,grayThreshold: 100)
        

        p.writeValue(Data(receipt.data),for: c, type: .withoutResponse)
    }
    
    
    
    func resizeAndPrintImage(sourceImage: UIImage, result: @escaping FlutterResult){
        let oldheight: CGFloat = sourceImage.size.height
        let oldWidth: CGFloat = sourceImage.size.width
        let scaleFactor: CGFloat = oldWidth / oldheight
        let newWidth: CGFloat = 560
        let newHeight: CGFloat = 560 / scaleFactor
        UIGraphicsBeginImageContext(CGSize(width: newWidth, height: newHeight))
        sourceImage.draw(in: CGRect(x: 0, y: 0, width: newWidth, height: newHeight))
        let newImage: UIImage = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()
        for y in stride(from: 0, to: newHeight, by: 200) {
            let rect = CGRect(x: 0, y: y, width: 560, height: (y + 200 >= newHeight) ? newHeight - y : 200)
            let croppedCGImage = newImage.cgImage?.cropping(to: rect)
            let croppedImage = UIImage(cgImage: croppedCGImage!)
            listCropImage.append(croppedImage)
            printImage(listImage: croppedImage)
        }
            result("Success !!!")

        
    }
    
   
    
    private func scanDevice(call: FlutterMethodCall, result: @escaping FlutterResult){
        if(bluetoothState == .unsupported) {
            return result(FlutterError.init(code: "error_no_bt", message: nil, details: nil))
        }
        else if(bluetoothState == .poweredOff) {
            CBCentralManager(delegate: nil, queue: nil,options: [CBCentralManagerOptionShowPowerAlertKey : true])
        }
        if(centralManager.isScanning) {
            disconnectAllPrinter()
            stopScan()
        }
        centralManager.scanForPeripherals(withServices: [CBUUID(string: "E7810A71-73AE-499D-8C15-FAA9AEF0C3F2")], options: nil)
        let bondedDevices = centralManager.retrieveConnectedPeripherals(withServices: [])
        var res = [Dictionary<String, String>]()
        for device in bondedDevices {
            res.append(toMap(device))
        }
        scanTimer = Timer.scheduledTimer(withTimeInterval: 15, repeats: false, block: {_ in self.stopScan() })
        
        result(res)
        
    }
    
    private func action_stop_scan(call: FlutterMethodCall, result: @escaping FlutterResult){
        stopScan()
        result(nil)
    }
    
    private func state(call: FlutterMethodCall, result: @escaping FlutterResult){
        if(bluetoothState == .poweredOn){
            result(true)
        }
        else if(bluetoothState == .poweredOff){
            result(false)
        }
    }
    
    private func connectDevice(call: FlutterMethodCall, result: @escaping FlutterResult){
        let id: String = call.arguments as! String
        let index = (id as NSString).integerValue
        peripheral = arrayPeripehral[index]
        centralManager.stopScan()
        centralManager?.connect(peripheral!,options: [CBConnectPeripheralOptionNotifyOnDisconnectionKey: true])
        result(true)
    }
    
    private func action_request_permissions(call: FlutterMethodCall, result: @escaping FlutterResult){
        if(bluetoothState == .unauthorized) {
            if #available(iOS 13.0, *) {
                switch centralManager.authorization {
                case .denied, .restricted, .notDetermined:
                    return result(FlutterError.init(code: "error_no_permission", message: nil, details: nil))
                case .allowedAlways:
                    break;
                }
            }
        }
        result(nil)
    }
    
    private func onPrint(call: FlutterMethodCall, result: @escaping FlutterResult){
        let arguments = call.arguments as? [String:Any]
        guard let bitmapInput = arguments!["bitmapInput"] as?  FlutterStandardTypedData else {
            return
        }
        guard var image = UIImage(data: bitmapInput.data) else {
            return
        }
        resizeAndPrintImage(sourceImage: image,result:result)
        
    }
    
    
    func stopScan() {
        scanTimer?.invalidate()
        centralManager.stopScan()
        channel.invokeMethod("action_scan_stopped", arguments: nil)
    }
}
