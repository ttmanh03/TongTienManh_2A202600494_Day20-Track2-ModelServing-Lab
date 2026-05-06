# Reflection — Lab 20 (Personal Report)

> **Đây là báo cáo cá nhân.** Mỗi học viên chạy lab trên laptop của mình, với spec của mình. Số liệu của bạn không so sánh được với bạn cùng lớp — chỉ so sánh **before vs after trên chính máy bạn**. Grade rubric tính theo độ rõ ràng của setup + tuning của bạn, không phải tốc độ tuyệt đối.

---

**Họ Tên:** Tong Tien Manh
**Cohort:** 2A202600494
**Ngày submit:** 06-05-2026

---

## 1. Hardware spec (từ `00-setup/detect-hardware.py`)

> Mình chạy `python 00-setup/detect-hardware.py` để generate `hardware.json`, nhưng trên Windows máy mình script không đọc ra đúng CPU model/RAM và còn nhầm physical cores. Vì vậy mình **điền thủ công** dựa trên Windows CIM + log của `llama-server`.

- **OS:** Windows 11 Home Single Language (10.0.26200)
- **CPU:** 11th Gen Intel(R) Core(TM) i3-1115G4 @ 3.00GHz
- **Cores:** 2 physical / 4 logical
- **CPU extensions:** AVX2, AVX-512 (log `llama-server` báo `AVX512=1`)
- **RAM:** 11.7 GB
- **Accelerator:** CPU only
- **llama.cpp backend đã chọn:** CPU
- **Recommended model tier:** TinyLlama-1.1B (Q4_K_M)

**Setup story** (≤ 80 chữ): những gì cần thay đổi để lab chạy được trên máy bạn (vd: dùng WSL2, install CUDA Toolkit, fall back sang Vulkan vì ROCm phiên bản kén, tắt antivirus để pip install nhanh hơn, v.v.):

**Setup story (≤ 80 chữ):**
Mình chạy lab native trên Windows + `.venv`. Track 02 cần `/metrics` nên không dùng `python -m llama_cpp.server` (404 `/metrics`), mà build native `llama-server.exe` từ `llama.cpp` bằng MinGW. Quá trình build bị kẹt do Windows long path + lỗi `CreateFile2`, mình patch vendored `cpp-httplib` để compile được và chạy `llama-server --metrics`.

---

## 2. Track 01 — Quickstart numbers (từ `benchmarks/01-quickstart-results.md`)

> Paste bảng từ `benchmarks/01-quickstart-results.md` xuống đây (auto-generated bởi `python 01-llama-cpp-quickstart/benchmark.py`).

| Model | Load (ms) | TTFT P50/P95 (ms) | TPOT P50/P95 (ms) | E2E P50/P95/P99 (ms) | Decode rate (tok/s) |
|---|--:|--:|--:|--:|--:|
| tinyllama-1.1b-chat-v1.0.Q4_K_M.gguf | 785 | 227 / 318 | 35.5 / 60.8 | 2230 / 2955 / 3104 | 28.2 |
| tinyllama-1.1b-chat-v1.0.Q2_K.gguf | 481 | 408 / 533 | 35.5 / 39.6 | 2643 / 2739 / 2745 | 28.2 |

**Một quan sát** (≤ 50 chữ): Q4_K_M vs Q2_K trên máy bạn — số liệu nói gì? Quality đáng đánh đổi không?

Q4_K_M cho chất lượng tốt hơn rõ rệt, và trên máy mình tốc độ decode gần như tương đương Q2_K (decode rate giống nhau). Điểm khác là TTFT của Q2_K lại cao hơn (có thể do biến thiên đo/OS cache), nhưng tổng thể mình chọn Q4_K_M vì chất lượng.

---

## 3. Track 02 — llama-server load test

> Chạy 2 lần locust ở concurrency 10 và 50, paste tóm tắt bên dưới.

> Ghi chú: `locust` trong lab này đo **response time end-to-end** (không tách riêng streaming TTFB). Vì vậy mình dùng P50/P95/P99 từ “Response time percentiles (Aggregated)” làm số liệu latency.

| Concurrency | Total RPS | E2E P50 (ms) | E2E P95 (ms) | E2E P99 (ms) | Failures |
|--:|--:|--:|--:|--:|--:|
| 10 | 0.37 | 22000 | 28000 | 33000 | 0 |
| 50 | 0.49 | 27000 | 47000 | 49000 | 0 |

**KV-cache observation (metrics):**
- Khi chạy native `llama-server --metrics`, endpoint `/metrics` của build mình đang dùng **không export** các series `llamacpp:kv_cache_*` nên `record-metrics.py` không lấy được `llamacpp:kv_cache_usage_ratio`.
- Thay vào đó mình dùng dấu hiệu contention từ metric có sẵn trong CSV:
	- u=10: `llamacpp:requests_deferred` max = 6 (ít queue)
	- u=50: `llamacpp:requests_deferred` max = 46 và `llamacpp:requests_processing` max = 4 (đúng bằng `--parallel 4`), nghĩa là hệ thống bị **queueing mạnh** khi số user tăng.

Artifacts: `benchmarks/02-server-metrics-u10.csv`, `benchmarks/02-server-metrics-u50.csv`.

---

## 4. Track 03 — Milestone integration

- **N16 (Cloud/IaC):** stub: localhost only (không deploy lên K8s/Cloud trong lab này)
- **N17 (Data pipeline):** stub: TOY_DOCS trong code
- **N18 (Lakehouse):** stub
- **N19 (Vector + Feature Store):** stub: retrieval bằng keyword overlap trên `TOY_DOCS` (không dùng vector DB)

**Nơi tốn nhiều ms nhất** trong pipeline (đo bằng `time.perf_counter` trong `pipeline.py`):

- embed: 0 ms (stub — không chạy embedder)
- retrieve: ~0.0–0.1 ms (TOY retrieval)
- llama-server: ~9818–16784 ms (3 queries mẫu)

**Reflection** (≤ 60 chữ): bottleneck nằm ở đâu? Có khớp với kỳ vọng không?

Bottleneck gần như toàn bộ nằm ở bước gọi `llama-server` (LLM inference). Retrieval gần như “free” vì đang stub; nếu thay bằng vector DB + embedder thật thì retrieve sẽ tăng đáng kể nhưng vẫn thường nhỏ hơn inference trên CPU.

---

## 5. Bonus — The single change that mattered most

> **Most important section.** Pick **một** thay đổi từ bonus track (build flag, thread sweep, quant pick, GPU offload, KV-cache quantization, speculative decoding, bất cứ challenge nào trong `BONUS-llama-cpp-optimization/CHALLENGES.md`) đã tạo ra speedup lớn nhất trên máy bạn.

**Change:** Tune số thread `-t` cho decode (giảm từ 4 xuống 2).

**Before vs after** (paste 2-3 dòng từ sweep output):

```
before: -t 4  tg64 ≈ 20.8 tok/s
after:  -t 2  tg64 ≈ 22.9 tok/s
speedup: ~1.10×
```

**Tại sao nó work** (1–2 đoạn ngắn — đây là phần grader đọc kỹ nhất):

Trên CPU nhỏ (i3-1115G4: 2C/4T), decode của LLM thường **memory-bandwidth-bound** hơn là compute-bound. Khi tăng thread lên mức logical cores (4) thì các thread tranh nhau băng thông RAM/L3 và overhead scheduling tăng, nên tok/s không tăng tương ứng.

Với `-t 2` (gần sát physical cores), mỗi core làm việc “thật” hơn, ít tranh chấp hơn → decode tok/s tăng. Kết quả thread sweep đúng trực giác: `-t 2` tốt hơn `-t 4`.

Artifact: `benchmarks/bonus-thread-sweep.md`.

---

## 6. (Optional) Điều ngạc nhiên nhất

_(1–2 câu — không bắt buộc, nhưng người grader đọc tất cả)_

Điều ngạc nhiên: tăng concurrency từ 10 → 50 làm latency P95/P99 tăng rất mạnh, nhưng Total RPS lại tăng nhẹ (0.37 → 0.49). Điều này giống “continuous batching” trong deck: throughput có thể tăng nhờ gom batch, nhưng tail latency trả giá.

---

## 7. Self-graded checklist

- [x] `hardware.json` đã commit
- [x] `models/active.json` đã commit
- [x] `benchmarks/01-quickstart-results.md` đã commit
- [x] CSV từ `record-metrics.py` đã commit (`benchmarks/02-server-metrics-u10.csv`, `benchmarks/02-server-metrics-u50.csv`)
- [x] `benchmarks/bonus-*.md` đã commit (`benchmarks/bonus-thread-sweep.md`)
- [x] Ít nhất 6 screenshots trong `submission/screenshots/`
- [x] `make verify` exit 0 (chạy ngay trước khi push)
- [ ] Repo trên GitHub ở chế độ **public**
- [ ] Đã paste public repo URL vào VinUni LMS

---

**Quan trọng:** repo phải **public** đến khi điểm được công bố. Nếu private, grader không xem được → 0 điểm.
