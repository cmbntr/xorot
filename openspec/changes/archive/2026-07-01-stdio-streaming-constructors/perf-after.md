## Pipe-mode post-change

- Command shape: `zig build -Doptimize=ReleaseFast && /usr/bin/time -f 'elapsed_s=%e max_rss_kb=%M' sh -c 'dd if=/dev/zero bs=1M count=128 status=none | ./zig-out/bin/xorot > /dev/null'`
- Environment: `Linux 7.0.13-200.fc44.x86_64 #1 SMP PREEMPT_DYNAMIC Fri Jun 19 22:51:30 UTC 2026 x86_64 GNU/Linux`, `zig 0.16.0`, native repo-local build
- Observed result values: `elapsed_s=0.10`, `max_rss_kb=4708`
- Comparison note: result is effectively flat versus baseline (`0.09s` -> `0.10s`), consistent with the design expectation that any benefit is small and startup-oriented.
