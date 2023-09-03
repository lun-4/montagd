# montagd
montage-ish binary built on libgd

## how

- get zig 0.11.0 https://ziglang.org
- get libgd and respective library headers

```
git clone ...
cd ...
zig build
```

note: `zig build -Dcpu=<microarchitecture>`, e.g `skylake_avx512` or `znver3`
