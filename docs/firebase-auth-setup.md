# Cấu hình Firebase Authentication

UC01–UC02 đã có giao diện và tích hợp Firebase Authentication/Cloud Firestore. Khi chưa có cấu hình Firebase, ứng dụng mở ở chế độ xem trước: có thể xem các màn hình và kiểm tra xác thực biểu mẫu, nhưng đăng nhập/đăng ký/gửi email đặt lại mật khẩu chưa gọi dịch vụ thật.

## Tạo cấu hình cục bộ

1. Tạo Firebase project và thêm Android app với package name `com.example.smart_todo`.
2. Trong Firebase Authentication, bật phương thức `Email/Password`.
3. Tạo Firestore database.
4. Lấy các giá trị sau từ Firebase Console → Project settings → General → Your apps. Có thể lấy `apiKey`, `mobilesdk_app_id`, `project_number`, `project_id`, và `storage_bucket` tương ứng trong `google-services.json`.
5. Tạo file `firebase_config.json` ở thư mục gốc repo (file này đã được ignore):

```json
{
  "FIREBASE_API_KEY": "your-api-key",
  "FIREBASE_APP_ID": "1:123456789:android:abcdef",
  "FIREBASE_MESSAGING_SENDER_ID": "123456789",
  "FIREBASE_PROJECT_ID": "your-project-id",
  "FIREBASE_STORAGE_BUCKET": "your-project-id.firebasestorage.app"
}
```

6. Cho phép mỗi người dùng tạo và cập nhật hồ sơ của chính mình trong Firestore Security Rules. Ví dụ phần rule cho `users/{uid}`:

```text
match /users/{uid} {
  allow read, create, update: if request.auth != null
    && request.auth.uid == uid;
}
```

Không dùng rule này thay cho các rule riêng của board/card và không bật quyền đọc/ghi công khai.

## Chạy Android

```powershell
flutter pub get
flutter run --dart-define-from-file=firebase_config.json
```

Ứng dụng dùng trạng thái xác thực Firebase để tự điều hướng. Firebase Authentication trên Android tự duy trì phiên sau khi ứng dụng đóng/mở lại; nút đăng xuất gọi `signOut()`. Đăng ký tạo tài khoản Email/Password, cập nhật tên hiển thị và tạo `users/{uid}`. Đặt lại mật khẩu gửi email bằng Firebase Authentication.

Nếu không có file cấu hình, đăng nhập và đăng ký hiển thị thông báo hướng dẫn; không tạo tài khoản giả trên thiết bị.
