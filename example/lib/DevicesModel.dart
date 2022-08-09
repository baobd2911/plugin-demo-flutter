
class DevicesModel{
  String name;
  String address;
  bool state;

  DevicesModel(this.name,this.address,this.state);

  @override
  String toString() {
    return "Name: " + name + "-" + "Address: " + address;
  }
}