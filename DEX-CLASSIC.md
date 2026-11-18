# Dex classic

This branch is `main` as of January 2024, the last state of Dex in which the
whole pipeline runs, plus fixes and new examples. It exists so that Dex
programs can be written and run while the compiler rewrite on
`kind-for-plain-old-data` is unfinished.

## What is on it

- `lib/fft.dx` and `lib/set.dx` ported to the current syntax and inference
  (upstream pull requests 1347 and 1348).
- `lib/ode.dx`: the Dormand-Prince ODE solver, moved out of
  `examples/ode-integrator.dx` and repaired.
- `examples/blackhole.dx`: a Kerr black hole raytracer. The geodesic equations
  come from differentiating a Hamiltonian.
- `examples/blackhole-room.dx`: the same black hole inside the room from
  `examples/raytrace.dx`.
- `misc/blackhole-room-film.sh`: renders a film of that room.
- `lib/simplex.dx`: a linear programming solver, rewritten from the old
  `examples/simplex.dx`, whose syntax no longer existed. The tableau's rows
  and columns are indexed by enums.
- `examples/physics.dx`: disks falling into a box, where each time step is a
  linear program solved by that library.
- The notebook frontend typesets LaTeX in prose again.

## Running things

    dex --lib-path lib script examples/blackhole.dx
    dex --lib-path lib generate-html examples/blackhole.dx dex-lang/examples/blackhole

The second command writes a page under `pages/`. To view it, copy
`static/index.js` and `static/style.css` into `pages/dex-lang/static/` and run
`make serve-docs`. `static/index.js` is built from `static/index.ts` by
`make static/index.js`.

Everything here was run with a binary built from `main` in July 2024. Building
this branch from scratch has not been tried since.

## What works

These reproduce their expected output exactly: the examples `mandelbrot`, `pi`,
`sierpinski`, `mcmc`, `raytrace`, `ode-integrator`, `blackhole`,
`blackhole-room`, `simplex` and `physics`, and the tests `set-tests` and
`fft-tests`.

## Known problems

- Most other examples fail, nearly all because type inference is now
  forward-only and they need annotations. `examples/brownian_motion.dx` runs
  but its output differs from what the file expects.
- Dependent table types do not work. The `(..i)` range syntax no longer
  parses, and a table of type `(i:n) => RangeTo i => a` crashes the compiler.
  `lib/linalg.dx` is built on these, so it and everything that imports it
  (`psd`, `kernelregression`, `linear-maps`, `linalg-tests`) fail to load.
- Comparison operators bind more tightly than arithmetic in some positions:
  `a + b < c` can parse as `a + (b < c)`. Parenthesize.
- `/` only divides by a single-precision `Float`. For `Float64`, use `divide`.
- `-O` prints a stray `> []` after each definition, so `make run-examples/...`,
  which passes `-O`, fails for every example.
- `misc/check-quine` uses a GNU-only option of `diff` and fails on macOS.
  Comparing `dex script file.dx` with `file.dx` using plain `diff` does the
  same job.
- A library module added after the cache was first written is recompiled on
  every run.
- `--backend llvm-mc` is accepted but evaluation stays on one core.
- `dex script --outfmt html` is rejected although the help lists it.
