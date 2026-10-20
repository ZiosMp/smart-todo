# Smart Todo

Ứng dụng Flutter quản lý công việc cho sinh viên Đại học Công nghiệp Hà Nội, sử dụng Firebase Authentication và Cloud Firestore.

Repo này khởi tạo cấu trúc và các điểm mở rộng theo 8 use case trong `docs/use-cases.md`. Chức năng nghiệp vụ và cấu hình Firebase thực tế cần được hoàn thiện theo từng bước.

## Phạm vi theo đặc tả

- UC01–UC02: đăng ký, đăng nhập, ghi nhớ phiên và đặt lại mật khẩu.
- UC03: danh sách board, tạo/sửa, lưu trữ/khôi phục; Owner và Member có quyền khác nhau.
- UC04–UC05: quản lý, sắp xếp list và card; trạng thái hoàn thành, lưu trữ, chi tiết, checklist, nhãn.
- UC06: mời thành viên, chấp nhận/từ chối, phân công và bình luận.
- UC07: hạn chót, mục “Công việc của tôi”, trạng thái deadline và nhắc trước 24 giờ.
- UC08: tìm kiếm tiêu đề không phân biệt dấu/chữ hoa thường và lọc card.

## Bắt đầu

Yêu cầu Flutter SDK tương thích với Dart `>=3.10.0 <4.0.0`.

```sh
flutter pub get
dart format lib
flutter run
```

Repo chỉ cấu hình runner Android. Kết nối điện thoại đã bật USB debugging hoặc khởi động AVD trong Android Studio, sau đó chạy `flutter run`.

UC01–UC02 có giao diện đăng nhập/đăng ký, xác thực biểu mẫu, duy trì phiên, đặt lại mật khẩu và đăng xuất. Để kết nối dịch vụ Firebase thật, làm theo [hướng dẫn cấu hình Firebase](docs/firebase-auth-setup.md). Không commit file cấu hình cá nhân `firebase_config.json`.

Khi chưa cấu hình Firebase, ứng dụng mở màn hình đăng nhập ở chế độ xem trước; các yêu cầu xác thực sẽ chỉ ra cấu hình còn thiếu, không giả lập tạo tài khoản. Khu vực công việc sau đăng nhập vẫn là dữ liệu mẫu trong bộ nhớ. Không commit service account, secret, hoặc file `firebase_config.json`.

## Cấu trúc

```text
lib/
  app/                 cấu hình ứng dụng, theme, điều hướng
  core/                tiện ích và thành phần dùng chung
  features/            auth, boards, lists, cards, collaboration,
                       deadlines, search
  main.dart
docs/
  use-cases.md
  firestore-schema.md
```

Mỗi feature được chia thành `data`, `domain`, `presentation` để tách Firebase khỏi giao diện và quy tắc nghiệp vụ. State management dùng Riverpod; điều hướng dùng go_router.

## Nguồn yêu cầu

Các use case được tổng hợp từ tài liệu đặc tả được cung cấp. Xem [docs/use-cases.md](docs/use-cases.md) và [docs/firestore-schema.md](docs/firestore-schema.md).
