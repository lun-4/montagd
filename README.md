# montagd
montage-ish binary built on libgd

## how

- get zig 0.13.0 https://ziglang.org
- get libgd and respective library headers

```
git clone ...
cd ...
zig build

# for production
zig build -Doptimize=ReleaseSafe -Dcpu=skylake_avx512
# or
zig build -Doptimize=ReleaseSafe -Dcpu=znver3
# etc, use `zig targets` to find out
```
