# Feature modules

Tạo từng feature theo cấu trúc `data/`, `domain/`, `presentation/`. Repository interface thuộc domain; triển khai Firestore/Auth thuộc data; widget và Riverpod providers thuộc presentation hoặc application layer. Tránh để widget gọi Firebase trực tiếp.

Feature dự kiến: `auth`, `boards`, `lists`, `cards`, `collaboration`, `deadlines`, `search`.
