# Bonus — Thread sweep

Model: `tinyllama-1.1b-chat-v1.0.Q4_K_M.gguf`  ·  GPU layers: `0`

| threads | tg64 (tok/s) |
|---:|---:|
| 1 | 18.0 |
| 2 | 22.9 |
| 4 | 20.8 |

**Best**: `-t 2` at 22.9 tok/s.

Look at the curve. If it peaks around your **physical** core count and drops as you go higher, that's the memory-bandwidth ceiling: extra threads fight over the same memory channels and slow each other down.
