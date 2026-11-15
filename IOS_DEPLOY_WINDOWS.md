# Triển khai Locket Studio lên iOS (iPhone) từ máy Windows

Do Xcode chỉ chạy trên macOS, dự án đã được cấu hình sẵn **GitHub Actions** (và dự phòng **Codemagic**) để biên dịch ứng dụng Flutter thành file cài đặt `.ipa` trên đám mây, sau đó cài trực tiếp vào iPhone từ Windows qua **Sideloadly** hoặc **AltStore** mà không cần máy Mac hay tài khoản Apple Developer trả phí ($99/năm).

---

## Phần 1: Tạo file `LocketStudio-unsigned.ipa` bằng GitHub Actions (Miễn phí)

1. Tạo một repository mới trên GitHub (có thể để Private hoặc Public).
2. Mở Terminal tại `d:\D\Locket` và đẩy mã nguồn lên GitHub:
   ```powershell
   git init
   git add .
   git commit -m "Initial Locket Studio iOS & Android"
   git branch -M main
   git remote add origin https://github.com/<USERNAME>/<REPO_NAME>.git
   git push -u origin main
   ```
3. Mở repository trên GitHub, vào tab **Actions** → chọn workflow **Build iOS Unsigned IPA** (workflow tự chạy khi push lên `main`/`master`, hoặc bấm **Run workflow** để chạy thủ công).
4. Sau khi build hoàn tất (~4–6 phút), kéo xuống mục **Artifacts** và tải file **`LocketStudio-iOS-IPA`** (giải nén sẽ được `LocketStudio-unsigned.ipa`).

> **Dự phòng với Codemagic**: File `codemagic.yaml` đã được tạo sẵn ở thư mục gốc nếu bạn muốn kết nối repo vào Codemagic và chạy workflow `ios-unsigned-ipa`.

---

## Phần 2: Cài đặt file `.ipa` vào iPhone từ Windows bằng Sideloadly

1. Trên máy Windows, cài đặt:
   - **iTunes** (tải bản cài đặt trực tiếp từ Apple, không dùng bản Microsoft Store) và **iCloud for Windows** (chỉ cần cài, không nhất thiết đăng nhập nếu Sideloadly nhận thiết bị).
   - **Sideloadly** (tải từ trang chủ `https://sideloadly.io`).
2. Cắm cáp USB kết nối iPhone với máy tính Windows và bấm **Tin cậy (Trust)** trên iPhone.
3. Mở **Sideloadly**:
   - Kéo thả file `LocketStudio-unsigned.ipa` vào ô IPA.
   - Nhập **Apple ID** miễn phí của bạn.
   - Bấm **Start** và nhập mật khẩu / mã xác thực 2FA nếu được hỏi.
4. Trên iPhone (sau khi cài xong):
   - **Tin cậy chứng chỉ nhà phát triển**: Vào *Cài đặt* → *Cài đặt chung* → *Quản lý VPN & Thiết bị* → chọn Apple ID của bạn → bấm **Tin cậy (Trust)**.
   - **Bật Chế độ nhà phát triển (iOS 16 trở lên)**: Vào *Cài đặt* → *Quyền riêng tư & Bảo mật* → kéo xuống cuối bật **Chế độ nhà phát triển (Developer Mode)** và khởi động lại máy nếu iOS yêu cầu.

> **Lưu ý khi dùng Apple ID miễn phí**: Chứng chỉ ký ứng dụng miễn phí có hiệu lực **7 ngày**. Bạn có thể bật tùy chọn **Wi-Fi Sideloading / Auto-refresh** trong Sideloadly (hoặc AltServer/AltStore) để tự động gia hạn qua Wi-Fi khi máy tính và iPhone cùng mạng.

---

## Phần 3: Kết hợp Phím tắt iOS (iOS Shortcuts) với Locket Studio

Ngoài nút **"Lưu vào Album & Mở Locket"** có sẵn ngay trong ứng dụng, bạn có thể tạo một Phím tắt nhanh trên iPhone:
1. Mở ứng dụng **Phím tắt (Shortcuts)** trên iPhone → bấm **+**.
2. Thêm tác vụ **Mở ứng dụng (Open App)** → chọn **Locket Studio** để xử lý ảnh `1080×1080` (Photobooth 2×2, khung viền PNG, sticker, thanh caption).
3. Sau khi bấm **Lưu vào Album & Mở Locket** trong Locket Studio, ảnh vuông `1080×1080 px` (< 2MB) sẽ nằm ngay đầu Album **"Locket Studio"** và mục **Gần đây (Recents)**, sẵn sàng để bạn chọn và đăng lên Locket Widget.
