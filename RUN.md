# Chạy ứng dụng Smart Todo trên Android

Hướng dẫn dành cho Windows và Android Studio. Ứng dụng chỉ chạy trên Android.

## 1. Chuẩn bị công cụ

Cài các công cụ sau nếu máy chưa có:

- Git for Windows
- Android Studio
- Flutter SDK

Trong Android Studio, mở **Tools → SDK Manager** và cài Android SDK, Android SDK Platform-Tools và Android SDK Command-line Tools. Trong **Plugins**, cài plugin **Flutter** (plugin Dart sẽ được cài kèm nếu Android Studio yêu cầu).

Giải nén Flutter SDK vào một thư mục dễ nhớ, ví dụ `C:\src\flutter`. Không đặt SDK trong thư mục project. Thêm `C:\src\flutter\bin` vào biến môi trường `Path`, sau đó đóng và mở lại Android Studio.

Mở Terminal mới và kiểm tra:

```powershell
flutter --version
flutter doctor
```

Nếu lệnh `flutter` chưa được nhận diện, hãy dùng đường dẫn SDK đầy đủ, ví dụ:

```powershell
& "C:\src\flutter\bin\flutter.bat" --version
```

## 2. Clone repo từ GitHub

1. Sao chép HTTPS hoặc SSH URL của repo từ GitHub, ví dụ `https://github.com/<tài-khoản>/<tên-repo>.git`.
2. Tại màn hình Welcome của Android Studio, chọn **Get from VCS**. Nếu đã mở một project, chọn **File → New → Project from Version Control**.
3. Chọn Git, dán URL repo, chọn thư mục lưu project rồi nhấn **Clone**.
4. Nếu GitHub yêu cầu, đăng nhập hoặc cấu hình SSH key/token để máy có quyền đọc repo.
5. Sau khi clone, Android Studio có thể hỏi có tin cậy project hay mở cửa sổ mới; chọn **Trust Project** và chờ Gradle/IDE đồng bộ xong.

Mở **thư mục gốc của repo**, là thư mục chứa `pubspec.yaml` và thư mục `android`. Không mở riêng thư mục `android`.

## 3. Cấu hình Flutter trong Android Studio

Nếu Android Studio chưa tìm thấy Flutter SDK, mở **File → Settings → Languages & Frameworks → Flutter**, bật Flutter support và chọn đường dẫn SDK, ví dụ `C:\src\flutter`. Chọn **Apply** rồi **OK**.

Mở Terminal ở thư mục gốc repo và chạy:

```powershell
flutter doctor
flutter pub get
```

Nếu Flutter chưa được thêm vào `Path`, thay lệnh thứ hai bằng đường dẫn SDK đầy đủ:

```powershell
& "C:\src\flutter\bin\flutter.bat" pub get
```

Nếu `flutter doctor` báo thiếu Android licenses, chạy:

```powershell
flutter doctor --android-licenses
```

Đọc và chấp nhận các license, rồi chạy lại `flutter doctor`.

## 4. Tạo và khởi động Android Emulator

1. Trong Android Studio chọn **Tools → Device Manager**.
2. Nếu chưa có máy ảo, chọn **Create Device**, chọn một mẫu điện thoại, chọn/tải Android system image rồi hoàn tất tạo thiết bị.
3. Nhấn nút **▶** cạnh thiết bị để khởi động emulator.
4. Đợi emulator hiện màn hình chính. Kiểm tra thiết bị đã sẵn sàng:

```powershell
flutter devices
```

Danh sách cần có thiết bị Android, ví dụ `emulator-5554`. ID trên máy bạn có thể khác.

## 5. Chạy ứng dụng

Trong Terminal tại thư mục gốc repo, chạy lệnh dưới đây và thay ID bằng ID Android hiện ra ở bước trước:

```powershell
flutter run -d emulator-5554
```

Hoặc chọn emulator trong danh sách thiết bị ở thanh công cụ Android Studio rồi nhấn **Run ▶**. Nếu Android Studio không hiện cấu hình chạy, mở `lib/main.dart` và nhấn Run.

Dừng ứng dụng chạy trong Terminal bằng `q` hoặc `Ctrl+C`.

## 6. Firebase và chế độ xem trước

Repo chưa chứa cấu hình Firebase riêng. Khi chưa được kết nối Firebase, app mở ở chế độ xem trước; có thể xem giao diện nhưng đăng ký, đăng nhập và gửi email đặt lại mật khẩu chưa xác thực tài khoản thật.

Để dùng xác thực thật, chủ project cần tạo/cấu hình Firebase Android app theo `docs/firebase-auth-setup.md`. Mỗi người dùng cần lấy cấu hình hợp lệ từ Firebase project được cấp quyền. Không đưa API secrets, service account hay file cấu hình cá nhân vào commit công khai.

## Xử lý lỗi thường gặp

- **`flutter` is not recognized**: kiểm tra Flutter SDK đã cài chưa; thêm thư mục `flutter\bin` vào `Path`, mở Terminal/Android Studio mới, hoặc dùng đường dẫn đầy đủ như ví dụ trên.
- **`No supported devices found`**: bật emulator trong Device Manager, chờ khởi động xong, chạy lại `flutter devices`, rồi dùng đúng ID đang được liệt kê.
- **Android licenses chưa chấp nhận**: chạy `flutter doctor --android-licenses`.
- **Dependency/build lỗi sau khi pull**: ở thư mục có `pubspec.yaml`, chạy `flutter pub get`; kiểm tra `flutter doctor` và thông báo Gradle cụ thể.
