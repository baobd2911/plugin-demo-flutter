
class DevicesModel{
  String name;
  String address;

  DevicesModel(this.name,this.address);

  @override
  String toString() {
    return "Name: " + name + "-" + "Address: " + address;
  }
}