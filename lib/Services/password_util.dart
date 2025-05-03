import 'package:bcrypt/bcrypt.dart';

class PasswordUtil {
  bool checkPassword(String password, String hashed){
    return BCrypt.checkpw(password, hashed);
  }
}