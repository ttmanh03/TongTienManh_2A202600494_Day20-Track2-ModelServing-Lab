# Hướng Dẫn Thực Hiện Bài Lab Day 20

## 1. Giới thiệu
Lab này tập trung vào việc xây dựng và tối ưu hóa inference stack với llama.cpp trên laptop cá nhân. Mục tiêu là đo các chỉ số TTFT, TPOT, P50, P95, P99 và viết báo cáo cá nhân về thay đổi tối ưu mang lại hiệu quả lớn nhất.

**Yêu cầu:**
- Laptop cá nhân (Windows, macOS, hoặc Linux).
- Python ≥ 3.10.
- Trên **Windows**, khuyến nghị **Python 3.10–3.12** (Python 3.13 có thể khiến `llama-cpp-python` phải build từ source và dễ lỗi như Windows Long Path / thiếu toolchain).
- Không cần Docker hoặc OpenAI key.

---

## 2. Chuẩn bị

### 2.1. Cài đặt môi trường
1. **Windows:**
    - Khuyến nghị dùng **PowerShell 7** (`pwsh`). Lệnh setup “one-shot”:
       ```powershell
       pwsh -ExecutionPolicy Bypass -File 00-setup\windows-setup.ps1
       ```
       Nếu máy bạn chưa có `pwsh`, thường có thể chạy bằng Windows PowerShell 5.1:
       ```powershell
       powershell -ExecutionPolicy Bypass -File 00-setup\windows-setup.ps1
       ```
    - Lưu ý quan trọng: script này không chỉ “cài đặt”, mà còn **tự chạy**:
       - Tạo `.venv/` và cài `requirements.txt` + `llama-cpp-python`
       - Chạy `00-setup/detect-hardware.py` → tạo `hardware.json`
       - Chạy `00-setup/download-model.py` → tải 2 file GGUF (Q4_K_M + Q2_K) và tạo `models/active.json`
    - Nếu bạn muốn **tự tải model thủ công** (không download từ Hugging Face): làm theo `00-setup/MANUAL-DOWNLOAD.md`, rồi chạy:
       ```powershell
       python 00-setup\download-model.py --skip-download
       ```

2. **macOS/Linux:**
   - Chạy script tương ứng trong thư mục `00-setup/`:
     ```bash
     ./00-setup/macos-setup.sh  # macOS
     ./00-setup/linux-setup.sh  # Linux
     ```

3. **Kiểm tra phần cứng:**
   - Chạy lệnh sau để tạo file `hardware.json`:
   ```powershell
   python 00-setup\detect-hardware.py
   ```

### 2.2. Tải model
- Script `00-setup/download-model.py` sẽ tự động tải model phù hợp dựa trên file `hardware.json`.
- Nếu gặp lỗi mạng, xem hướng dẫn trong `00-setup/MANUAL-DOWNLOAD.md`.

---

## 3. Thực hiện các track

Trước khi chạy các track, hãy đảm bảo bạn đang ở repo root và đã activate venv:

- Windows:
   ```powershell
   .\.venv\Scripts\Activate.ps1
   ```
- macOS/Linux:
   ```bash
   source .venv/bin/activate
   ```

### 3.1. Track 01: Quickstart
1. Chạy benchmark để đo TTFT, TPOT, P50, P95, P99:
    ```bash
    python 01-llama-cpp-quickstart/benchmark.py
    ```
2. Kết quả sẽ được lưu trong `benchmarks/01-quickstart-results.md`.

### 3.2. Track 02: Server
1. Khởi chạy server:
    - Windows:
       ```powershell
       pwsh -ExecutionPolicy Bypass -File 02-llama-cpp-server\start-server.ps1
       ```
    - macOS/Linux:
       ```bash
       bash 02-llama-cpp-server/start-server.sh
       ```
2. Kiểm tra server hoạt động:
   ```bash
    python 02-llama-cpp-server/smoke-test.py
   ```
3. Chạy load test với Locust:
   - 10 người dùng:
     ```bash
       locust -f 02-llama-cpp-server/load-test.py --headless -u 10 -r 1 -t 1m --host http://localhost:8080
     ```
   - 50 người dùng:
     ```bash
       locust -f 02-llama-cpp-server/load-test.py --headless -u 50 -r 1 -t 1m --host http://localhost:8080
     ```
4. Ghi lại các chỉ số KV-cache:
   Lưu ý quan trọng:
   - Script [02-llama-cpp-server/record-metrics.py](02-llama-cpp-server/record-metrics.py) scrape `http://localhost:8080/metrics`.
   - Nếu bạn đang chạy server bằng `python -m llama_cpp.server` (tức các launcher `start-server.ps1/.sh` trong track này), endpoint `/metrics` sẽ **404** (vì `llama_cpp.server` không có flag `--metrics`). Khi đó `record-metrics.py` sẽ báo `scrape failed` và kết thúc với `no samples collected`.

   Muốn có `/metrics`, bạn cần chạy **native** `llama-server` (llama.cpp) với `--metrics` (xem `BONUS-llama-cpp-optimization/01-build-from-source.md`). Sau khi server native đang chạy, mới chạy:

    **Windows (ví dụ dùng binary đã build trong repo):**
    - Mở 1 terminal (giữ chạy foreground) và chạy:
       ```powershell
       .\BONUS-llama-cpp-optimization\llama.cpp\build-mingw\bin\llama-server.exe `
          -m .\models\tinyllama-1.1b-chat-v1.0.Q4_K_M.gguf `
          --host 0.0.0.0 --port 8080 --metrics
       ```
    - Kiểm tra nhanh `/metrics` phải **không** là 404:
       ```powershell
       curl.exe -s -o NUL -w "HTTP=%{http_code}\n" http://localhost:8080/metrics
       curl.exe -s http://localhost:8080/metrics | findstr /n "." | Select-Object -First 10
       ```
       Nếu thấy `HTTP=404` thì bạn đang chạy nhầm server (thường là `llama_cpp.server` từ `start-server.ps1/.sh`).

    Sau đó, mở terminal khác và chạy `record-metrics.py`:
   ```bash
   python 02-llama-cpp-server/record-metrics.py --duration 60
   ```

### 3.3. Track 03: Integration
1. Chạy pipeline:
   ```bash
    python 03-milestone-integration/pipeline.py
   ```
2. Đảm bảo pipeline chạy end-to-end và in ra provenance của context.

### 3.4. Bonus Tracks (Tùy chọn)
- Build llama.cpp từ source:
  ```bash
  make build-llama
  ```
- Chạy các sweep script để tối ưu:
  ```bash
  make sweep-thread
  make sweep-quant
  make sweep-ctx
  make sweep-batch
  make sweep-gpu
  ```
- Thử thách mở trong `BONUS-llama-cpp-optimization/CHALLENGES.md`.

---

## 4. Nộp bài
1. Thêm các ảnh chụp màn hình vào `submission/screenshots/` (xem danh sách trong `submission/screenshots/README.md`).
2. Điền đầy đủ `submission/REFLECTION.md`.
3. Chạy lệnh kiểm tra cuối cùng:
   ```bash
   python scripts/verify.py
   ```
4. Push repo lên GitHub (public) và gửi link vào LMS.

**Lưu ý:** Repo phải để public đến khi điểm được công bố.

---

## 5. Tham khảo
- **HARDWARE-GUIDE.md:** Chọn model và backend phù hợp.
- **VIBE-CODING.md:** Áp dụng phương pháp BMAD để tối ưu workflow.
- **rubric.md:** Đảm bảo đáp ứng đầy đủ các tiêu chí chấm điểm.

---

## Troubleshooting nhanh (Windows)

### Lỗi: `ERROR: llama_cpp not installed`

Nguyên nhân thường gặp: `llama-cpp-python` chưa được cài trong đúng `.venv` hoặc pip không kéo được wheel từ PyPI.

Chạy các lệnh sau (trong repo root):

```powershell
 .\.venv\Scripts\Activate.ps1
 pip install --upgrade --extra-index-url https://abetlen.github.io/llama-cpp-python/whl/cpu llama-cpp-python
 python -c "import llama_cpp; print('llama_cpp OK')"
```

Chúc bạn hoàn thành bài lab thành công!