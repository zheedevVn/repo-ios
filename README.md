# 📦 repo-ios — ZheeDev iOS Jailbreak Repository

<p>
  <img src="https://img.shields.io/github/actions/workflow/status/zheedevVn/repo-ios/build-repo.yml?label=Build&logo=github" alt="build"/>
  <img src="https://img.shields.io/badge/iOS-Jailbreak-ff3b30?logo=apple&logoColor=white" alt="iOS jailbreak"/>
  <img src="https://img.shields.io/badge/arch-iphoneos--arm64-blue" alt="arm64"/>
</p>

Kho tweak iOS của **ZheeDev** — mã nguồn được build tự động bằng GitHub Actions và phát hành qua GitHub Pages dưới dạng kho APT chuẩn, tương thích **Sileo / Cydia / Zebra** trên iPhone đã jailbreak (arm64).

## ➕ Thêm nguồn

Thêm URL sau vào trình quản lý tweak của bạn:

```
https://zheedevVn.github.io/repo-ios/
```

## 📲 Danh sách tweak

| Tweak | Package | Phiên bản | Mô tả |
|---|---|---|---|
| 🎬 **Ứng Dụng Xem Video** | `com.zheedev.videoapp` | 1.2.4 | Xem video trực tuyến chất lượng cao với trình phát WebKit mượt mà |
| 📊 **Thông Tin Thiết Bị** | `com.zheedev.devicestats` | 1.2.2 | Phân tích & hiển thị toàn diện thông số phần cứng, hệ điều hành, pin thực tế và mạng |

### 🎬 Ứng Dụng Xem Video (`com.zheedev.videoapp`)
- Xem video trực tuyến chất lượng cao
- Trình phát WebKit mượt mà, tối ưu cho iPhone
- Thuộc nhóm Multimedia

### 📊 Thông Tin Thiết Bị — DeviceStats (`com.zheedev.devicestats`)
- Thông số phần cứng & hệ điều hành chi tiết
- Dung lượng pin **thực tế** đọc trực tiếp từ IOKit (IOPMPowerSource)
- Thông tin mạng của thiết bị
- Thuộc nhóm Utilities

## 🤖 Build & phát hành tự động

Mỗi lần push lên nhánh `main`, GitHub Actions sẽ tự động:

1. Build 2 package `.deb` bằng **Theos** (iPhoneOS SDK)
2. Quét và sinh danh sách `Packages` chuẩn APT (`Packages`, `Packages.gz`, `Packages.bz2`) cùng file `Release`
3. Deploy lên **GitHub Pages**

## 📁 Cấu trúc repo

```
repo-ios/
├── app/                 # Source tweak Ứng Dụng Xem Video (Theos)
├── infoapp/             # Source tweak Thông Tin Thiết Bị (Theos)
├── index.html           # Trang web giới thiệu repo
├── Release              # File Release chuẩn APT
└── .github/workflows/   # CI: build .deb & deploy Pages
```

## ⚠️ Yêu cầu

- iPhone đã **jailbreak**, kiến trúc **iphoneos-arm64**
- Trình quản lý tweak: Sileo / Cydia / Zebra

## 👤 Tác giả

**ZheeDev** — https://github.com/zheedevVn
