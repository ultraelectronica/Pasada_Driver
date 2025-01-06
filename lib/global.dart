//this class is used for data changes when a button is pressed. it doesn't work on the same class but i might implement this in the database class. for now. this is what im gonna use.


class GlobalVar {
  static final GlobalVar _instance = GlobalVar._internal();
  bool isOnline = false;

  // void checkDriverStatus() {
  //   String status = MainPageState().driverStatus;
  //   print(status);
  //   if (status != "Online") {
  //     print("global variable isOnline is true!");
  //     isOnline = true;
  //   } else {
  //     print("global variable isOnline is false!");
  //     isOnline = false;
  //   }
  // }


  factory GlobalVar() {
    return _instance;
  }

  GlobalVar._internal();
}
