// import 'package:bcrypt/bcrypt.dart';
// import 'package:flutter/foundation.dart';

// class PasswordUtils {
//   // Default cost factor for bcrypt (higher is more secure but slower)
//   static const int _defaultLogRounds = 12;

//   /// Hashes a password using bcrypt
//   ///
//   /// Returns a hashed password string
//   static String hashPassword(String password) {
//     try {
//       // Generate a salt and hash the password
//       final String salt = BCrypt.gensalt(logRounds: _defaultLogRounds);
//       final String hashedPassword = BCrypt.hashpw(password, salt);
//       return hashedPassword;
//     } catch (e) {
//       if (kDebugMode) {
//         print('Error hashing password: $e');
//       }
//       // Return an empty string or throw an exception based on your error handling strategy
//       throw Exception('Failed to hash password: $e');
//     }
//   }

//   /// Verifies a password against a hashed password
//   ///
//   /// Returns true if the password matches the hash, false otherwise
//   static bool verifyPassword(String password, String hashedPassword) {
//     try {
//       // Check if the password matches the hash
//       return BCrypt.checkpw(password, hashedPassword);
//     } catch (e) {
//       if (kDebugMode) {
//         print('Error verifying password: $e');
//       }
//       // Return false on error
//       return false;
//     }
//   }
// }
