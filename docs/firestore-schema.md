# Firestore data model (proposal)

Schema này là đề xuất kỹ thuật để hiện thực các use case, cần được kiểm tra cùng Firestore Security Rules trước khi triển khai. Dùng ID tài liệu cho tham chiếu; lưu `createdAt`/`updatedAt` dạng Firestore Timestamp và dùng server timestamp khi ghi.

```text
users/{uid}
  displayName, email, createdAt, updatedAt
users/{uid}/inbox/{invitationId}
  boardId, boardName, inviterUid, inviterName, status, createdAt

boards/{boardId}
  name, description, ownerId, memberIds[], archivedAt?, createdAt, updatedAt
boards/{boardId}/members/{uid}
  role: owner|member, joinedAt, displayName, email
boards/{boardId}/invitations/{invitationId}
  email, normalizedEmail, invitedBy, status: pending|accepted|declined,
  createdAt, updatedAt
boards/{boardId}/lists/{listId}
  name, position, archivedAt?, createdAt, updatedAt
boards/{boardId}/cards/{cardId}
  listId, title, description, position, isCompleted, assigneeIds[],
  labelIds[], dueAt?, archivedAt?, createdBy, createdAt, updatedAt
boards/{boardId}/cards/{cardId}/checklist/{itemId}
  title, isCompleted, position, createdAt, updatedAt
boards/{boardId}/cards/{cardId}/comments/{commentId}
  authorId, authorName, body, createdAt, updatedAt
boards/{boardId}/labels/{labelId}
  name, color
```

## Ràng buộc và lưu ý

- `memberIds` hỗ trợ truy vấn board tham gia; subcollection `members` giữ vai trò và thông tin thành viên. Mọi ghi phải duy trì nhất quán giữa hai cấu trúc, tốt nhất qua transaction/batch hoặc trusted backend.
- Lời mời đặt trong board để Owner quản lý; inbox theo UID để người nhận thấy lời mời sau đăng nhập. Khi gửi, chỉ tạo inbox cho tài khoản tìm thấy bằng email chuẩn hóa; nếu email chưa đăng ký thì cần chính sách sản phẩm khác.
- `assigneeIds` chỉ được chứa UID thuộc membership hiện hành. Gỡ Member phải cập nhật các card liên quan.
- Đổi thứ tự nhiều list/card cần ghi nhất quán (transaction/batch) và có thể cần thiết kế lại nếu board lớn.
- Firestore query có giới hạn, yêu cầu composite indexes ở một số kết hợp lọc; bổ sung index theo truy vấn thực tế.
- Nhắc 24 giờ trước deadline cần lập lịch trên thiết bị và quyền notification. Gỡ/cập nhật deadline hoặc hoàn thành card phải hủy nhắc cũ. Nhắc trên mọi thiết bị cần backend đáng tin cậy.
- Không xem quy tắc UI là bảo mật. Security Rules phải kiểm tra membership/role và quyền sửa từng trường; không cho client tự nâng quyền Owner hoặc ghi tùy ý vào hồ sơ người khác.
- Chưa đưa Firestore Rules mẫu vào repo vì quyền chéo board/member/card cần khớp chính xác với schema và hành vi triển khai; rules mở mặc định là không an toàn.
