import Flutter
import UIKit
import CoreBluetooth
import Foundation

@available(iOS 10.0, *)
extension SwiftClvNhacvoPrintPlugin: CBCentralManagerDelegate,CBPeripheralDelegate ,CBPeripheralManagerDelegate {
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
        peripheral.discoverServices(nil)
        channel.invokeMethod("action_connected", arguments: checkIsConnect)
    }
    
//    public func centralManager(_ central: CBCentralManager, didDisConnect peripheral: CBPeripheral) {
//        print("Disconnected!")
//        checkIsConnect = true
//        peripheral.discoverServices(nil)
//    }
    
    public func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
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

        for char in service.characteristics ?? [] {
//            print("Discovered char: \(char.uuid.uuidString)")
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
    var arrayPeripehral = [CBPeripheral]()
    var checkIsConnect: Bool = false


    init(_ channel: FlutterMethodChannel) {
        self.channel = channel
        super.init()
        centralManager.delegate = self
    }

    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "flutter_scan_bluetooth", binaryMessenger: registrar.messenger())
        let instance = SwiftClvNhacvoPrintPlugin(channel)
        registrar.addMethodCallDelegate(instance, channel: channel)
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult)   {
        switch call.method {
        case "scanDevice":
            if(bluetoothState == .unsupported) {
                return result(FlutterError.init(code: "error_no_bt", message: nil, details: nil))
            }
            else if(bluetoothState == .poweredOff) {
                CBCentralManager(delegate: nil, queue: nil,options: [CBCentralManagerOptionShowPowerAlertKey : true])
            }
            if(centralManager.isScanning) {
                stopScan()
            }
            centralManager.scanForPeripherals(withServices: [CBUUID(string: "E7810A71-73AE-499D-8C15-FAA9AEF0C3F2")], options: nil)
//            centralManager.scanForPeripherals(withServices: nil, options: nil)

            let bondedDevices = centralManager.retrieveConnectedPeripherals(withServices: [])
            var res = [Dictionary<String, String>]()
            for device in bondedDevices {
                res.append(toMap(device))
            }
            scanTimer = Timer.scheduledTimer(withTimeInterval: 15, repeats: false, block: {_ in self.stopScan() })
            result(res)
            break;
        case "action_stop_scan":
            stopScan()
            result(nil)
            break;
        case "state":
            if(bluetoothState == .poweredOn){
                result(true)
            }
            else if(bluetoothState == .poweredOff){
                result(false)
            }
            break
        case "connectDevice":
            let id: String = call.arguments as! String
            print(id)
            let index = (id as NSString).integerValue
            let peripheral = arrayPeripehral[index]
            peripheral.delegate = self
            centralManager.stopScan()
            centralManager?.connect(peripheral,options: nil)
            break;
        case "action_request_permissions":
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
            break;
        default:
            result(FlutterMethodNotImplemented);
        }
    }

    func stopScan() {
        scanTimer?.invalidate()
        centralManager.stopScan()
        channel.invokeMethod("action_scan_stopped", arguments: nil)
    }
}
