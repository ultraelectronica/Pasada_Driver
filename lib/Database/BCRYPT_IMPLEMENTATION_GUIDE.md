# Implementing BCrypt in Flutter - Step by Step Guide

This guide will walk you through implementing bcrypt password hashing in your Flutter application from scratch.

## Prerequisites

1. Add the bcrypt package to your pubspec.yaml:
   ```yaml
   dependencies:
     bcrypt: ^1.1.3
   ```

2. Run `flutter pub get` to install the package.

## Step 1: Understanding BCrypt

BCrypt is a password-hashing function designed to be slow and computationally expensive, making it resistant to brute-force attacks.

Key concepts:
- **Salt**: A random value added to the password before hashing to prevent rainbow table attacks
- **Cost/Rounds**: Controls how computationally expensive the hashing is (higher = more secure but slower)
- **Hash format**: `$2a$[cost]$[22 character salt][31 character hash]`

## Step 2: Create a Password Utility Class

Create a new file called `password_utils.dart` with the following structure:

```dart
import 'package:bcrypt/bcrypt.dart';
import 'package:flutter/foundation.dart';

class PasswordUtils {
  // Constants
  static const int _defaultLogRounds = 12;
  
  // Methods
  static String hashPassword(String password) {
    // Implementation here
  }
  
  static bool verifyPassword(String password, String hashedPassword) {
    // Implementation here
  }
}
```

## Step 3: Implement Password Hashing

Add the following implementation to the `hashPassword` method:

```dart
static String hashPassword(String password) {
  try {
    // Generate a salt with the specified number of rounds
    final String salt = BCrypt.gensalt(logRounds: _defaultLogRounds);
    
    // Hash the password with the generated salt
    final String hashedPassword = BCrypt.hashpw(password, salt);
    
    return hashedPassword;
  } catch (e) {
    if (kDebugMode) {
      print('Error hashing password: $e');
    }
    throw Exception('Failed to hash password: $e');
  }
}
```

## Step 4: Implement Password Verification

Add the following implementation to the `verifyPassword` method:

```dart
static bool verifyPassword(String password, String hashedPassword) {
  try {
    // Check if the password matches the hash
    return BCrypt.checkpw(password, hashedPassword);
  } catch (e) {
    if (kDebugMode) {
      print('Error verifying password: $e');
    }
    return false;
  }
}
```

## Step 5: Implement in Your Login Flow

Here's how to use bcrypt in your login flow:

```dart
Future<void> login(String username, String password) async {
  try {
    // 1. Fetch the user's data including the hashed password
    final userData = await fetchUserData(username);
    
    // 2. Get the stored hashed password
    final storedHashedPassword = userData['password'] as String;
    
    // 3. Verify the entered password against the stored hash
    final bool passwordMatches = PasswordUtils.verifyPassword(
      password, 
      storedHashedPassword
    );
    
    // 4. Handle authentication result
    if (passwordMatches) {
      // Password is correct, proceed with login
      navigateToHome();
    } else {
      // Password is incorrect, show error
      showErrorMessage('Invalid credentials');
    }
  } catch (e) {
    // Handle errors
    showErrorMessage('Login failed: $e');
  }
}
```

## Step 6: Implement User Registration

When creating a new user, hash the password before storing it:

```dart
Future<void> register(String username, String password) async {
  try {
    // 1. Hash the password
    final String hashedPassword = PasswordUtils.hashPassword(password);
    
    // 2. Create user data with the hashed password
    final userData = {
      'username': username,
      'password': hashedPassword,
      // other user data
    };
    
    // 3. Store in the database
    await storeUserData(userData);
    
    // 4. Proceed with post-registration flow
    showSuccessMessage('Registration successful');
    navigateToLogin();
  } catch (e) {
    // Handle errors
    showErrorMessage('Registration failed: $e');
  }
}
```

## Step 7: Additional Security Considerations

1. **Password Strength**: Implement password strength requirements
   ```dart
   bool isPasswordStrong(String password) {
     // At least 8 characters
     if (password.length < 8) return false;
     
     // Contains uppercase, lowercase, number, and special character
     final hasUppercase = password.contains(RegExp(r'[A-Z]'));
     final hasLowercase = password.contains(RegExp(r'[a-z]'));
     final hasNumber = password.contains(RegExp(r'[0-9]'));
     final hasSpecial = password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'));
     
     return hasUppercase && hasLowercase && hasNumber && hasSpecial;
   }
   ```

2. **Rate Limiting**: Implement rate limiting for login attempts

3. **Secure Storage**: Use secure storage for sensitive data
   ```dart
   import 'package:flutter_secure_storage/flutter_secure_storage.dart';
   
   final storage = FlutterSecureStorage();
   await storage.write(key: 'auth_token', value: token);
   ```

## Testing Your Implementation

Create a simple test to verify your implementation:

```dart
void testBcrypt() {
  const String password = 'SecurePassword123!';
  
  // Hash the password
  final String hashedPassword = PasswordUtils.hashPassword(password);
  print('Hashed: $hashedPassword');
  
  // Verify correct password
  final bool correctResult = PasswordUtils.verifyPassword(password, hashedPassword);
  print('Correct password verification: $correctResult'); // Should be true
  
  // Verify incorrect password
  final bool incorrectResult = PasswordUtils.verifyPassword('WrongPassword', hashedPassword);
  print('Incorrect password verification: $incorrectResult'); // Should be false
}
```

## Conclusion

By following these steps, you've implemented secure password hashing using bcrypt in your Flutter application. This approach protects your users' passwords even if your database is compromised.

Remember that security is an ongoing process. Stay updated with the latest security best practices and regularly review your implementation.
