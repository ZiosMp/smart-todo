# Kiểm thử UC03 – Quản lý Board

## 1. Phạm vi

Bộ kiểm thử workflow UC03 bao phủ 5 luồng nghiệp vụ được nêu trong đặc tả:

| Mã test | Chức năng | Kết quả cần xác nhận |
|---|---|---|
| UC03-01 | Xem danh sách Board | Người dùng chỉ truy vấn được Board mình tham gia; Board đã lưu trữ không xuất hiện trong danh sách chính |
| UC03-02 | Tạo Board | Tạo document Board và document Owner trong cùng batch; tên Board có độ dài 1–100 ký tự |
| UC03-03 | Sửa Board | Owner sửa được tên/mô tả; Member không được sửa |
| UC03-04 | Lưu trữ Board | Owner đặt `archivedAt`; Board vẫn tồn tại nhưng bị loại khỏi danh sách đang hoạt động |
| UC03-05 | Khôi phục Board | Owner đặt `archivedAt = null`; Board xuất hiện lại trong danh sách đang hoạt động |

File kiểm thử: `firebase/tests/firestore.uc03.workflow.test.mjs`.

Đây là kiểm thử tích hợp ở tầng Firestore Security Rules và dữ liệu. Nó không tự động bấm nút hoặc kiểm tra điều hướng Flutter. Việc mở màn hình chi tiết sau khi tạo Board vẫn cần được kiểm tra thủ công hoặc bổ sung Widget Test riêng.

## 2. Chuẩn bị môi trường

Yêu cầu Node.js phiên bản 22 trở lên (theo `firebase/package.json`), Flutter và Firebase CLI đã được cài đặt.

Mở PowerShell tại thư mục gốc dự án:

```powershell
cd "D:\smart todo"
```

Cài dependency khi mới tải code hoặc khi chưa có `firebase/node_modules`:

```powershell
npm --prefix firebase ci
```

## 3. Chạy riêng 5 test workflow UC03

Lệnh dưới đây tự khởi động Firestore Emulator, chạy file UC03 mới rồi tự tắt Emulator:

```powershell
npx firebase-tools emulators:exec --only firestore --project demo-smart-todo "node --test firebase/tests/firestore.uc03.workflow.test.mjs"
```

Kết quả mong đợi trong phần tổng kết:

```text
tests 5
pass 5
fail 0
```

## 4. Chạy toàn bộ kiểm thử Firestore

Từ thư mục gốc dự án, chạy:

```powershell
npx firebase-tools emulators:exec --only firestore --project demo-smart-todo "npm --prefix firebase run test:rules"
```

Script `test:rules` lần lượt chạy:
- `firestore.rules.test.mjs`: kiểm thử quyền Firestore chung.
- `firestore.uc03.rules.test.mjs`: kiểm thử các quy tắc quyền UC03.
- `firestore.uc03.workflow.test.mjs`: kiểm thử 5 luồng nghiệp vụ Board.
- `firestore.uc05.rules.test.mjs`: kiểm thử quyền Firestore UC05.

## 5. Cách đọc kết quả

- Dòng bắt đầu bằng `✔` nghĩa là test tương ứng đã đạt.
- Dòng `PERMISSION_DENIED` có thể là kết quả mong đợi ở test âm tính, khi test cố tình thực hiện thao tác trái quyền. Chỉ kết luận theo kết quả `pass/fail` cuối cùng.
- `Script exited successfully (code 0)` nghĩa là lệnh kiểm thử đã kết thúc thành công.
- Nếu có `ERR_MODULE_NOT_FOUND`, cài dependency bằng `npm --prefix firebase ci`, rồi chạy lại.

## 6. Kiểm tra giao diện Flutter

Bộ test Firestore không thay thế kiểm thử giao diện. Để kiểm tra ứng dụng:
1. Khởi động cả Auth và Firestore Emulator:

   ```powershell
   npx firebase-tools emulators:start --only auth,firestore --project demo-smart-todo
   ```

2. Mở PowerShell thứ hai và chạy:

   ```powershell
   cd "D:\smart todo"
   flutter test
   flutter analyze
   flutter run --dart-define=USE_FIREBASE_EMULATORS=true
   ```

3. Đăng ký/đăng nhập, tạo Board, sửa tên/mô tả, lưu trữ, mở danh sách Board đã lưu trữ, khôi phục và mở chi tiết Board.

## 7. Căn cứ đặc tả

Các bước nghiệp vụ, giới hạn tên Board 1–100 ký tự và quyền Owner/Member được lấy từ UC03 – Quản lý Board trong tài liệu đặc tả use case của dự án.
