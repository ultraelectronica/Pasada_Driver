# Services

This directory contains various services for the PASADA Driver app.

## Encryption Service

The `EncryptionService` provides encryption and decryption capabilities for both text data and images using the `cryptography` package.

### Features

- **Dual Encryption Support**: Supports both V2 (XOR-based) and V3 (AES-GCM) encryption methods
- **Image Encryption**: Specialized methods for encrypting/decrypting image data
- **Backward Compatibility**: Automatically detects and handles both encrypted and plain data
- **Error Handling**: Comprehensive error handling with fallback values
- **Environment Configuration**: Uses environment variables for master encryption keys

## ID Image Service

The `IdImageService` handles fetching and processing ID images from various sources including Supabase storage, encrypted references, and base64 data.

### Features

- **Multi-source Support**: Handles Supabase storage, URLs, base64, and encrypted references
- **Automatic Decryption**: Automatically decrypts encrypted image references
- **Error Handling**: Comprehensive error handling for different image sources
- **Storage Integration**: Direct integration with Supabase storage buckets

## Usage

### Encryption Service Setup

```dart
import 'package:pasada_driver_side/Services/encryption_service.dart';

final encryptionService = EncryptionService();
await encryptionService.initialize();
```

### Text Data Encryption/Decryption

```dart
// Encrypt text data
String encryptedText = await encryptionService.encryptUserData("sensitive data");

// Decrypt text data
String decryptedText = await encryptionService.decryptUserData(encryptedText);
```

### Image Data Encryption/Decryption

```dart
// Encrypt image bytes
Uint8List imageBytes = // ... your image data
String encryptedImage = await encryptionService.encryptImageData(imageBytes);

// Decrypt image data
Uint8List decryptedImage = await encryptionService.decryptImageData(encryptedImage);
```

### ID Image Service Setup

```dart
import 'package:pasada_driver_side/Services/id_image_service.dart';

final idImageService = IdImageService();
```

### Fetching ID Images

```dart
// Fetch image from various sources (Supabase storage, URLs, base64, encrypted)
Uint8List imageBytes = await idImageService.fetchBytes(imageReference);
```

### Batch Operations

```dart
// Encrypt multiple fields
Map<String, String> userData = {
  'name': 'John Doe',
  'email': 'john@example.com',
  'phone': '+1234567890'
};
Map<String, String> encryptedData = await encryptionService.encryptUserFields(userData);

// Decrypt multiple fields
Map<String, String> decryptedData = await encryptionService.decryptUserFields(encryptedData);
```

## Environment Configuration

The service requires an environment variable for V3 encryption:

```env
ENCRYPTION_MASTER_KEY_B64=your_base64_encoded_32_byte_key
```

## Integration with showIDDialog

The `showIDDialog` in `passenger_list_widget.dart` automatically handles various image sources:

```dart
// The dialog will automatically handle encrypted, Supabase storage, or base64 images
showIDDialog(context, imageReference, bookingId);
```

## Error Handling

Both services provide comprehensive error handling:

- **Decryption Failures**: Returns `[ENCRYPTED_DATA_RECOVERY_NEEDED]` for failed decryptions
- **Image Decryption**: Throws exceptions with descriptive error messages
- **Network Errors**: Handles HTTP errors and network timeouts
- **Storage Errors**: Handles Supabase storage access issues
- **Fallback Values**: Provides sensible defaults for common field types

## Security Notes

- V3 encryption uses AES-GCM with 256-bit keys
- V2 encryption uses XOR with device-specific keys (legacy support)
- Master keys should be stored securely in environment variables
- The service automatically detects encryption method based on data prefixes
- Supabase storage uses signed URLs for secure access
